#!/bin/bash
# Make Claude Code ask me before any tool call that could kill processes it didn't start (a PreToolUse hook, registered
# in `~/.claude/settings.json`). It checks every string in the tool's input (a Bash command, a file Claude is writing,
# an edit), so a kill hidden in a heredoc or in a script Claude writes is caught too. It can't catch a kill that is
# built at run time (e.g. decoded from base64).
#
# Added after a `pkill -f <pattern> -P <pid>` force-closed all my open terminals. macOS pkill ignores -P when it comes
# after the pattern, so it killed every process matching the pattern.

input=$(cat)
text=$(jq -r '[.tool_input | .. | strings] | join("\n")' <<<"$input") || exit 1

reasons=()

# Kill by name or pattern
grep -Eq '\b(pkill|killall)\b' <<<"$text" && reasons+=('pkill/killall (kills by name or pattern)')

# Kill by a PID list that comes from searching for processes (e.g. `kill $(pgrep x)`, `pgrep x | xargs kill`)
if grep -Eq '\bkill\b' <<<"$text" && grep -Eq '\b(pgrep|pidof|lsof|ps)\b' <<<"$text"; then
  reasons+=('kill combined with a process search (pgrep/pidof/lsof/ps)')
fi

# Kill every process (-1) or a whole process group (0 or a negative PID), e.g. `kill -9 -1`, `kill -- -123`
grep -Eq '\bkill\b[^;&|]*[[:space:]](0|-[0-9]+)[[:space:]]*($|[;&|)])' <<<"$text" &&
  reasons+=('kill aimed at all processes or a process group')

# Signals sent from code to a process group or to processes found by searching. A signal to a single PID (e.g.
# `os.kill(pid, ...)`) isn't checked, as that's how to signal a process Claude started itself, and a PID found by
# searching is caught by the process search check above.
grep -Eq '\bpsutil\b|\bkillpg\b' <<<"$text" && reasons+=('signal sent from code (psutil, killpg)')

(( ${#reasons[@]} )) || exit 0

joined=$(printf '%s; ' "${reasons[@]}")
reason="This may kill processes that Claude didn't start: ${joined%; }."
reason+=" Check that it only targets exact PIDs Claude started."
jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $reason
  }
}'
