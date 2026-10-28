#!/bin/bash
# Copy all files in this repo (relative to the repo root) into the corresponding location relative to the home directory
# (~), excluding .git and the repo's own scripts/docs. All the files in the repo are structured with this in mind, so
# running this script should place them all in the correct locations automatically.
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

# Ensure custom commands are accessible.
ZPROFILE="$HOME/.zprofile"  # Best place to put PATH exports
LOCAL_BIN="$HOME/.local/bin"  # Where custom commands are stored (already copied across as part of rsync)
LOCAL_PATH_EXPORT="export PATH=\"$LOCAL_BIN:\$PATH\""  # E.g. 'export PATH="/Users/thomas/.local/bin:$PATH"'
if ! grep -Fqx "$LOCAL_PATH_EXPORT" "$ZPROFILE" 2>/dev/null; then
  echo "$LOCAL_PATH_EXPORT" >> "$ZPROFILE"
fi

# Build my cmdlog program (for my custom ctrl+r, see .zshrc) from its source in this repo.
(cd "$script_dir/cmdlog" && go build -o "$LOCAL_BIN/cmdlog" .)

# Apply Maccy (clipboard history) settings with `defaults write` rather than by copying its preferences file (macOS
# caches preferences, so a copied file can be ignored or overwritten, and the file also holds window positions etc).
# Skip this if Maccy isn't installed (install.sh installs it).
if [ -d /Applications/Maccy.app ]; then
  # Set the settings changed from Maccy's defaults.
  #
  # Open with cmd+shift+v. The shortcut is a Carbon key code (9 = V) plus modifiers summed (cmd = 256, shift = 512, alt
  # = 2048, ctrl = 4096).
  defaults write org.p0deje.Maccy KeyboardShortcuts_popup -string '{"carbonKeyCode":9,"carbonModifiers":768}'
  defaults write org.p0deje.Maccy menuIcon -string paperclip
  defaults write org.p0deje.Maccy pasteByDefault -bool true  # Choosing an item pastes it, not just copies it.
  defaults write org.p0deje.Maccy removeFormattingByDefault -bool true
  defaults write org.p0deje.Maccy searchMode -string fuzzy
  defaults write org.p0deje.Maccy openPreviewAutomatically -bool true
  defaults write org.p0deje.Maccy previewDelay -int 500  # Milliseconds
  defaults write org.p0deje.Maccy showRecentCopyInMenuBar -bool false
  defaults write org.p0deje.Maccy SUEnableAutomaticChecks -bool false  # Homebrew handles updates.

  # Launch at login (not stored in Maccy's preferences, so can't be set with `defaults write`). macOS will ask for
  # permission for the terminal to control System Events the first time.
  if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q Maccy; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Maccy.app", hidden:true}' >/dev/null ||
      echo "warning: couldn't add Maccy as a login item. Enable 'Launch at login' in Maccy's settings instead." >&2
  fi

  # Restart Maccy so it picks up the settings.
  killall Maccy 2>/dev/null || true
  # Opening Maccy straight after killing it can fail with LaunchServices error -600, even once its process has exited
  # (LaunchServices can briefly still treat it as running), so retry for up to 5 seconds.
  attempts=0
  until open -a Maccy 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then
      open -a Maccy  # Final attempt, letting its error show
      break
    fi
    sleep 0.1
  done
fi
