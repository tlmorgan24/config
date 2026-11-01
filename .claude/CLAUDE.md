# Global instructions

- Never add any Claude or Claude Code attribution to anything you write: no "Generated with Claude Code" line, no Co-Authored-By trailer, no session link, no other watermark. This applies to commit messages, PR descriptions, issues, comments and files, in every project.
- Always write single-line commit messages unless instructed otherwise.
- Never push to GitHub unless explicitly instructed otherwise.
- Never kill processes by name or pattern (`pkill`, `killall`, `pgrep ... | xargs kill`, `kill $(pgrep ...)`, or the same from inside a script). Only kill exact PIDs of processes you started yourself in this session, and if you're unsure whether a process is mine, ask first. A pattern kill once force-closed every terminal I had open.
