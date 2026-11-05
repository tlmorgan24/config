#!/bin/bash
# Usage: `review.sh start <spec-file> [--rounds <n>] [--model <model>] [--base <commit>]`, then `review.sh respond`,
# then `review.sh summary`
#
# Have an independent reviewer (a separate headless Claude Code with read-only tools) check the changes made in the
# current Claude Code session against a spec I wrote. The writer (the session's Claude) runs this through `/review` (see
# `~/.claude/commands/review.md`). The reviewer's prompt is built here rather than by the writer, so the reviewer only
# ever sees the spec, the diff and the repo's files, never the writer's conversation or reasoning.
#
# The diff is against a snapshot of the repo taken when the session started (by `review.sh baseline`, a SessionStart
# hook), so changes I'd made before then are left out, but any I make by hand during the session are included. Pass
# --base to diff against a commit instead (e.g. for a session started before the hook was installed).
#
# `start` runs the first review and prints the findings. The writer then fixes or disputes each one, and passes its
# answers to `respond` on stdin, one per line (`F1 fixed`, or `F2 disputed <reason>`). That's one fix round, and it's
# always followed by another review, which checks the fixes and looks for new problems in them, so every fix is checked.
# --rounds is the most fix rounds the writer gets (default 1). With 0, the writer never sees the findings, and they all
# go straight to my summary. Problems found by the last review go to my summary too, as do disputed findings, which
# never go back to the reviewer (it would tend to be talked round by the writer's argument).
#
# The writer is only told when the review has finished, not what's in the summary. I see the summary by running
# `review.sh summary` myself (as `! ~/.claude/review/review.sh summary` in Claude Code), so it reaches me without going
# through the writer. The spec is copied when the review starts, so that changes to the original during review (by 
# Claude or me) don't affect anything.
set -euo pipefail

prompt_file=~/.claude/review/reviewer-prompt.md
state_root=~/.cache/claude-review

# The reviewer's answer for each review. `checks` is only filled from the second review on.
schema='{
  "type": "object",
  "properties": {
    "checks": {
      "type": "array",
      "description": "One entry per finding you were asked to check",
      "items": {
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "fixed": {"type": "boolean"},
          "note": {"type": "string", "description": "Why it is or is not fixed, briefly"}
        },
        "required": ["id", "fixed", "note"]
      }
    },
    "findings": {
      "type": "array",
      "description": "New problems found",
      "items": {
        "type": "object",
        "properties": {
          "severity": {"enum": ["high", "medium", "low"]},
          "file": {"type": "string", "description": "Path relative to the repo root"},
          "line": {"type": "integer"},
          "spec": {
            "type": "string",
            "description": "The spec requirement this breaks, or \"none\" for a bug the spec does not cover"
          },
          "claim": {"type": "string", "description": "What is wrong, with a concrete case where it goes wrong"}
        },
        "required": ["severity", "file", "line", "spec", "claim"]
      }
    }
  },
  "required": ["checks", "findings"]
}'

# Whether (in jq) the writer has findings to answer, i.e. there are some, and it has fix rounds left.
writer_turn='.reviews <= .rounds and any(.findings[]; .status == "open")'

# Format a finding (in jq) for printing.
show_finding='def show: "\(.id) [\(.severity)] \(.file):\(.line)\n  Spec: \(.spec)\n  Problem: \(.claim)";'

die() {
  echo "review: $*" >&2
  exit 1
}

# Print the hash of a git tree holding the working tree, including untracked files that aren't ignored, without
# touching the real index. Run from the repo root.
snapshot() {
  local tmp
  tmp=$(mktemp -d)
  # Start from a copy of the real index, so git only re-reads files that changed since it was last updated.
  cp "$(git rev-parse --git-path index)" "$tmp/index" 2>/dev/null || true
  GIT_INDEX_FILE=$tmp/index git add -A
  GIT_INDEX_FILE=$tmp/index git write-tree
  rm -rf "$tmp"
}

# Snapshot the repo at the start of a session (the SessionStart hook). Reads the hook's input on stdin.
baseline() {
  [[ -z ${CLAUDE_REVIEWER:-} ]] || return 0  # The reviewer's own session
  local input session cwd dir root tree
  input=$(cat)
  session=$(jq -r .session_id <<<"$input")
  cwd=$(jq -r .cwd <<<"$input")
  dir=$state_root/$session
  [[ ! -f $dir/base ]] || return 0  # A resumed session keeps its original snapshot.
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || return 0  # Not in a git repo
  tree=$(cd "$root" && snapshot)
  mkdir -p "$dir"
  printf '%s\n' "$root" > "$dir/root"
  printf '%s\n' "$tree" > "$dir/base"
}

start() {
  local spec='' rounds=1 model=sonnet base_commit='' root base
  while (( $# )); do
    case $1 in
      --rounds) rounds=${2:?--rounds needs a number}; shift 2 ;;
      --model) model=${2:?--model needs a model}; shift 2 ;;
      --base) base_commit=${2:?--base needs a commit}; shift 2 ;;
      -*) die "unknown option $1" ;;
      *) [[ -z $spec ]] || die "only one spec file can be given"; spec=$1; shift ;;
    esac
  done
  [[ -n $spec ]] || die 'usage: review.sh start <spec-file> [--rounds <n>] [--model <model>] [--base <commit>]'
  [[ -f $spec ]] || die "spec file not found: $spec"
  [[ $rounds =~ ^[0-9]+$ ]] || die "--rounds must be a whole number"
  spec=$(cd "$(dirname "$spec")" && pwd)/$(basename "$spec")

  if [[ -n $base_commit ]]; then
    root=$(git rev-parse --show-toplevel) || die "not in a git repo"
    base=$(git rev-parse --verify "$base_commit^{tree}") || die "not a commit: $base_commit"
  else
    [[ -f $dir/base ]] || die "there's no snapshot from the start of this session (it started outside a git repo, or" \
      "before the SessionStart hook was installed). Pass --base <commit> (e.g. a hash, branch or tag) to diff" \
      "against it instead."
    root=$(< "$dir/root")
    base=$(< "$dir/base")
  fi

  mkdir -p "$dir"
  # Copy the spec so the writer can't change it between reviews, and remove any earlier review's summary.
  cp "$spec" "$dir/spec.md"
  rm -f "$dir/summary.md"
  jq -n --arg spec "$spec" --arg model "$model" --argjson rounds "$rounds" --arg root "$root" --arg base "$base" \
    '{spec: $spec, model: $model, rounds: $rounds, reviews: 0, root: $root, base: $base, last: $base, findings: []}' \
    > "$state"
  run_review
}

# Run the next review, then print the findings for the writer to answer, or the summary if there are none or the writer
# has had all its fix rounds.
run_review() {
  local review rounds model root base last now diff prompt spec to_check reported out result
  review=$(( $(jq .reviews "$state") + 1 ))
  rounds=$(jq .rounds "$state")
  model=$(jq -r .model "$state")
  root=$(jq -r .root "$state")
  base=$(jq -r .base "$state")
  last=$(jq -r .last "$state")
  cd "$root"
  now=$(snapshot)
  diff=$(git diff "$base" "$now")
  if (( review == 1 )) && [[ -z $diff ]]; then
    echo 'No changes since the start of the session, so there is nothing to review.'
    rm "$state"
    return
  fi

  # Write the reviewer's prompt. The heredocs expand variables and `$(...)` (but not inside the values they insert), so
  # backticks in the text are escaped.
  prompt=$dir/prompt-$review.md
  spec=$(< "$dir/spec.md")
  cat > "$prompt" <<EOF
Review the changes in this repository (the working directory) against the spec below.

<spec>
$spec
</spec>

<diff description="All changes made against the spec so far">
$diff
</diff>

EOF
  if (( review == 1 )); then
    echo 'This is the first review, so leave `checks` empty.' >> "$prompt"
  else
    to_check=$(jq '[.findings[] | select(.status == "fixed") | {id, file, line, spec, claim}]' "$state")
    # Only the reviewer's own words, so it doesn't learn which findings were disputed, or why.
    reported=$(jq '[.findings[] | select(.status != "fixed") | {file, line, claim}]' "$state")
    cat >> "$prompt" <<EOF
Your earlier review reported these problems, and the author says it has fixed them. Check each one against the current
code, and give one entry in \`checks\` per finding.

<findings_to_check>
$to_check
</findings_to_check>

<diff description="Changes since your last review, made to fix those findings">
$(git diff "$last" "$now")
</diff>

These earlier findings have already been dealt with, so do not report them again.

<already_reported>
$reported
</already_reported>

Only report new findings for problems in the changes since your last review (e.g. a fix that breaks something else, or
only partly fixes the problem in a way not covered by the check above).
EOF
  fi

  echo "Review $review of up to $(( rounds + 1 )): the reviewer ($model) is reviewing..." >&2
  out=$(CLAUDE_REVIEWER=1 claude -p --model "$model" --append-system-prompt "$(< "$prompt_file")" \
    --tools Read,Grep,Glob --permission-prompts none --no-session-persistence \
    --output-format json --json-schema "$schema" < "$prompt") || die "the reviewer failed: $out"
  printf '%s\n' "$out" > "$dir/output-$review.json"
  result=$(jq -e 'select(.is_error == false) | .structured_output | objects' <<<"$out") ||
    die "the reviewer gave no usable answer (see $dir/output-$review.json)"
  jq -r '"The reviewer took \(.duration_ms / 1000 | round)s and cost $\(.total_cost_usd * 1000 | round / 1000)."' \
    <<<"$out" >&2

  # Record the checks (fixed → confirmed, or back to open with the reviewer's note) and add the new findings, most
  # severe first.
  jq --argjson result "$result" --argjson review "$review" --arg now "$now" '
    ($result.checks | map({key: .id, value: .}) | from_entries) as $checks
    | (.findings | length) as $count
    | .reviews = $review
    | .last = $now
    | .findings |= map(
        if .status == "fixed" and $checks[.id] then
          .note = $checks[.id].note | .status = (if $checks[.id].fixed then "confirmed" else "open" end)
        end)
    | .findings += [
        $result.findings
        | sort_by({high: 0, medium: 1, low: 2}[.severity])
        | to_entries[]
        | .value + {id: "F\($count + .key + 1)", review: $review, status: "open"}
      ]
  ' "$state" > "$state.tmp" && mv "$state.tmp" "$state"

  if jq -e "$writer_turn" "$state" >/dev/null; then
    print_open
  else
    finish
  fi
}

# Print the findings the writer has to answer, and how to answer them.
print_open() {
  jq -r "$show_finding"'
    "Fix round \(.reviews) of \(.rounds). Fix or dispute each of these findings:\n",
    (.findings[] | select(.status == "open") | show + (if .note then "\n  Not fixed yet: \(.note)" else "" end) + "\n"),
    "Then pass one line per finding to `~/.claude/review/review.sh respond` on stdin: `<id> fixed`, or `<id> disputed"
      + " <one-line reason>`. Fixed ones go back to the reviewer to check, and disputed ones go to the user."
  ' "$state"
}

# Record the writer's answers (on stdin), then run the next review if there are fixes to check.
respond() {
  [[ -f $state ]] || die "no review is in progress; run \`review.sh start <spec-file>\` first"
  jq -e "$writer_turn" "$state" >/dev/null ||
    die 'the review has finished. The user can see its summary with `! ~/.claude/review/review.sh summary`.'
  local answers problems
  answers=$(jq -R -s '[
    split("\n")[]
    | select(test("\\S"))
    | (capture("^\\s*(?<id>F[0-9]+)\\s+(?<answer>fixed|disputed)\\b\\s*(?<reason>.*)$"; "i")
       // error("cannot read this line (expected `<id> fixed` or `<id> disputed <reason>`): \(.)"))
    | .id |= ascii_upcase
    | .answer |= ascii_downcase
  ]' 2>&1) || die "${answers#*): }"
  problems=$(jq -r --argjson answers "$answers" '
    [.findings[] | select(.status == "open") | .id] as $open
    | ($answers | map(.id)) as $given
    | ($open - $given | if length > 0 then "no answer given for \(join(", "))" else empty end),
      ($given - $open | if length > 0 then "not waiting for an answer: \(join(", "))" else empty end),
      ($given | group_by(.) | map(select(length > 1)[0]) | if length > 0 then "answered twice: \(join(", "))"
        else empty end),
      ($answers[] | select(.answer == "disputed" and .reason == "") | "no reason given for disputing \(.id)")
  ' "$state")
  [[ -z $problems ]] || die "$problems"

  jq --argjson answers "$answers" '
    ($answers | map({key: .id, value: .}) | from_entries) as $a
    | .findings |= map(
        if $a[.id] then
          .status = $a[.id].answer | if $a[.id].answer == "disputed" then .reason = $a[.id].reason end
        end)
  ' "$state" > "$state.tmp" && mv "$state.tmp" "$state"

  if jq -e 'any(.findings[]; .status == "fixed")' "$state" >/dev/null; then
    run_review
  else
    finish
  fi
}

# Save the summary for me, and tell the writer the review has finished, without showing it the summary.
finish() {
  jq -r "$show_finding"'
    def section(title; condition; extra):
      [.findings[] | select(condition)] as $f
      | if ($f | length) > 0 then "\n## \(title)", ($f[] | "\n" + show + extra) else empty end;
    "# Review summary\n\nSpec: \(.spec)\nReviewer: \(.model)",
    "Reviews done: \(.reviews). Fix rounds allowed: \(.rounds).",
    if (.findings | length) == 0 then "\nThe reviewer found no problems." else empty end,
    section("Disputed by the writer (needs your decision)"; .status == "disputed"; "\n  Writer: \(.reason)"),
    section("Not fixed, according to the last review"; .status == "open" and .note; "\n  Reviewer: \(.note)"),
    section("Not seen by the writer (found in the last review)"; .status == "open" and (.note | not); ""),
    section("Fixed by the writer, but not covered by the last review"; .status == "fixed"; ""),
    section("Fixed, and confirmed by the reviewer"; .status == "confirmed"; "")
  ' "$state" > "$dir/summary.md"
  echo 'The review has finished. Tell the user to run `! ~/.claude/review/review.sh summary` to see its summary.'
}

# Print the summary of this session's last finished review, or of the newest one if not run from inside a Claude Code
# session.
summary() {
  local file
  if [[ -n ${CLAUDE_CODE_SESSION_ID:-} ]]; then
    file=$state_root/$CLAUDE_CODE_SESSION_ID/summary.md
  else
    file=$(ls -t "$state_root"/*/summary.md 2>/dev/null | head -n 1) || true
  fi
  [[ -f $file ]] || die "there's no finished review to show"
  cat "$file"
  echo "(Saved in $file)"
}

case ${1:-} in
  baseline) baseline ;;
  summary) summary ;;
  start | respond)
    dir=$state_root/${CLAUDE_CODE_SESSION_ID:?must be run from inside a Claude Code session}
    state=$dir/review.json
    "$1" "${@:2}"
    ;;
  *)
    die 'usage: review.sh start <spec-file> [--rounds <n>] [--model <model>] [--base <commit>], review.sh respond, or' \
      'review.sh summary'
    ;;
esac
