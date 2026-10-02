#!/bin/bash
# Copies all files in this repo (relative to the repo root) into the corresponding
# location relative to the home directory (~), excluding .git and this script itself.
# All the files in the repo are structured with this in mind, so running this script
# should place them all in the correct locations automatically
set -euo pipefail
script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

rsync -av \
  --filter=':- .gitignore' \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  --exclude="$(basename "$0")" \
  "$script_dir/" \
  "$HOME/"

# Ensure custom commands are accessible:
ZPROFILE="$HOME/.zprofile" # best place to put PATH exports
LOCAL_BIN="$HOME/.local/bin" # where custom commands stored (already copied across as part of rsync)
LOCAL_PATH_EXPORT="export PATH=\"$LOCAL_BIN:\$PATH\"" # e.g. 'export PATH="/Users/thomas/.local/bin:$PATH"'
if ! grep -Fqx "$LOCAL_PATH_EXPORT" "$ZPROFILE" 2>/dev/null; then
    echo "$LOCAL_PATH_EXPORT" >> "$ZPROFILE"
fi

# Ensure custom commands are executable:
# Custom command to run for zoxide/fzf previews (see .zshrc):
chmod +x "$LOCAL_BIN/lsf"
# Helpers for my custom fzf-based `browse` function (see .zshrc)
chmod +x "$LOCAL_BIN/browse-in"
chmod +x "$LOCAL_BIN/browse-out"
chmod +x "$LOCAL_BIN/provide-contents"
chmod +x "$LOCAL_BIN/display-contents"

chmod +x "$LOCAL_BIN/display-logs"

