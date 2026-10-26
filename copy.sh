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

# Maccy (clipboard history) settings, applied with `defaults write` rather than by copying its preferences file
# (macOS caches preferences, so a copied file can be ignored or overwritten, and the file also holds window positions etc)
# Skipped if Maccy isn't installed (install.sh installs it)
if [ -d /Applications/Maccy.app ]; then
  # Settings changed from Maccy's defaults
  # Shortcut is a Carbon key code (9 = V) plus modifiers summed (cmd = 256, shift = 512, alt = 2048, ctrl = 4096)
  defaults write org.p0deje.Maccy KeyboardShortcuts_popup -string '{"carbonKeyCode":9,"carbonModifiers":768}' # cmd+shift+v to open
  defaults write org.p0deje.Maccy menuIcon -string paperclip
  defaults write org.p0deje.Maccy pasteByDefault -bool true # choosing an item pastes it, not just copies it
  defaults write org.p0deje.Maccy removeFormattingByDefault -bool true
  defaults write org.p0deje.Maccy searchMode -string fuzzy
  defaults write org.p0deje.Maccy openPreviewAutomatically -bool true
  defaults write org.p0deje.Maccy previewDelay -int 500 # milliseconds
  defaults write org.p0deje.Maccy showRecentCopyInMenuBar -bool false
  defaults write org.p0deje.Maccy SUEnableAutomaticChecks -bool false # Homebrew handles updates

  # Launch at login (not stored in Maccy's preferences, so can't be set with `defaults write`)
  # macOS will ask for permission for the terminal to control System Events the first time
  if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q Maccy; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Maccy.app", hidden:true}' >/dev/null \
      || echo "warning: couldn't add Maccy as a login item. Enable 'Launch at login' in Maccy's settings instead." >&2
  fi

  # Restart Maccy so it picks up the settings
  killall Maccy 2>/dev/null || true
  # killall doesn't wait for Maccy to quit, and opening it while it's still quitting fails (LaunchServices error -600),
  # so wait (up to 5 seconds) for it to be gone first
  for _ in {1..50}; do
    pgrep -xq Maccy || break
    sleep 0.1
  done
  open -a Maccy
fi
