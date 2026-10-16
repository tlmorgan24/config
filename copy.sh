#!/bin/bash
# Copies all files in this repo (relative to the repo root) into the corresponding
# location relative to the home directory (~), excluding .git and the repo's own scripts/docs.
# All the files in the repo are structured with this in mind, so running this script
# should place them all in the correct locations automatically
set -euo pipefail
script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

rsync -av \
  --filter=':- .gitignore' \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  --exclude='cmdlog/' \
  --exclude='vscode-extensions.txt' \
  --exclude='/setup.sh' \
  --exclude='/install.sh' \
  --exclude='/copy.sh' \
  "$script_dir/" \
  "$HOME/"

# Ensure custom commands are accessible:
ZPROFILE="$HOME/.zprofile" # best place to put PATH exports
LOCAL_BIN="$HOME/.local/bin" # where custom commands stored (already copied across as part of rsync)
LOCAL_PATH_EXPORT="export PATH=\"$LOCAL_BIN:\$PATH\"" # e.g. 'export PATH="/Users/thomas/.local/bin:$PATH"'
if ! grep -Fqx "$LOCAL_PATH_EXPORT" "$ZPROFILE" 2>/dev/null; then
    echo "$LOCAL_PATH_EXPORT" >> "$ZPROFILE"
fi

# Build my cmdlog program (for my custom ctrl+r - see .zshrc) from its source in this repo
(cd "$script_dir/cmdlog" && go build -o "$LOCAL_BIN/cmdlog" .)

