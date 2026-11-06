---
description: Have an independent reviewer check this session's changes against a spec file
argument-hint: <spec-file> [--rounds <n>] [--model <model>] [--base <commit>]
allowed-tools: Bash(~/.claude/review/review.sh *)
---

Get an independent review of the changes made in this session, against the spec in the file given, as follows.

1. Run `~/.claude/review/review.sh start $ARGUMENTS` with the Bash tool, in the background (`run_in_background`) as a review can take several minutes. Inform the user that the review is in progress, and wait to be notified that it has finished. If it says there's nothing to review, tell the user and stop. Don't add anything to the reviewer's input. The script gives the reviewer only the spec and the code, so that it stays independent of this conversation.
2. For each finding it prints, decide honestly whether the reviewer is right.
   - If it is, or you can't show that it's wrong, fix it.
   - If you're confident it's wrong (e.g. it misreads the spec or the code), dispute it, with a one-line reason the user can check.

   Don't make any changes beyond what the findings need, and don't give commentary to the user.
3. Run `~/.claude/review/review.sh respond` in the background, with one line per finding on stdin: `<id> fixed` followed by a one-line description of what you changed, or `<id> disputed` followed by your reason, e.g.

   ```
   ~/.claude/review/review.sh respond <<'EOF'
   F1 fixed parse() now returns early on empty input instead of indexing into it
   F2 disputed The spec only asks for X when Y, which this case isn't
   EOF
   ```

   It sends the fixed findings back to the reviewer to check (without your descriptions, which only go to the user's summary). If it prints more findings for you (new ones, or ones the reviewer says aren't fixed yet), go back to step 2.
4. When it says the review has finished (straight after step 1, if `--rounds 0` was given), inform the user, "The review has finished. I've pasted its summary below:". Then paste the summary message, copied exactly (everything between `<message>` and `</message>`, without those tags), and stop.

Don't change, shorten or comment on the summary. Don't explain the findings or fixes/disputes you made. You may only do so in later responses, if the user requests you to.

If the script prints an error at any point (e.g. that there's no snapshot from the start of the session), tell the user and stop, rather than working around it.
