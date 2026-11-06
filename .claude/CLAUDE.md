# Global instructions

- Never add any Claude or Claude Code attribution to anything you write: no "Generated with Claude Code" line, no Co-Authored-By trailer, no session link, no other watermark. This applies to commit messages, PR descriptions, issues, comments and files, in every project.
- Always write single-line commit messages unless instructed otherwise.
- Never push to GitHub unless explicitly instructed otherwise.
- Never kill processes by name or pattern (`pkill`, `killall`, `pgrep ... | xargs kill`, `kill $(pgrep ...)`, or the same from inside a script). Only kill exact PIDs of processes you started yourself in this session, and if you're unsure whether a process is mine, ask first. A pattern kill once force-closed every terminal I had open.
- Never hide, filter or silence a warning (e.g. with `grep -v`, `--no-deprecation` or `2>/dev/null`) unless its root cause is fixed. Trace where it comes from first, and fix the cause if it's in our code or how we use a tool. If it can't be fixed (e.g. it's a bug in the tool itself), leave it showing and say where it comes from. I prefer a truthful warning to a hidden, unfixed one.
