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
  --exclude='/README.md' \
  --exclude='/VERSIONS.md' \
  --exclude='/cmdlog/' \
  --exclude='/rebase/' \
  --exclude='/vscode-extensions.txt' \
  --exclude='/vscode-copy-reference/' \
  --exclude='/setup.sh' \
  --exclude='/install.sh' \
  --exclude='/copy.sh' \
  --exclude='/versions.sh' \
  "$script_dir/" \
  "$HOME/"

# Ensure custom commands are accessible.
ZPROFILE="$HOME/.zprofile"  # Best place to put PATH exports
LOCAL_BIN="$HOME/.local/bin"  # Where custom commands are stored (already copied across as part of rsync)
LOCAL_PATH_EXPORT="export PATH=\"$LOCAL_BIN:\$PATH\""  # E.g. 'export PATH="/Users/thomas/.local/bin:$PATH"'
if ! grep -Fqx "$LOCAL_PATH_EXPORT" "$ZPROFILE" 2>/dev/null; then
  echo "$LOCAL_PATH_EXPORT" >> "$ZPROFILE"
fi

# Build my cmdlog program (see README.md) from its source in this repo.
(cd "$script_dir/cmdlog" && go build -o "$LOCAL_BIN/cmdlog" .)
# Build my rebase program (see README.md) from its source in this repo.
(cd "$script_dir/rebase" && go build -o "$LOCAL_BIN/rebase" .)
# Build my pick program (see README.md) from its source in this repo.
(cd "$script_dir/rebase" && go build -o "$LOCAL_BIN/pick" .)
# Build my drop program (see README.md) from its source in this repo.
(cd "$script_dir/rebase" && go build -o "$LOCAL_BIN/drop" .)
# Build my checkout program (see README.md) from its source in this repo.
(cd "$script_dir/rebase" && go build -o "$LOCAL_BIN/checkout" .)

# Create venv for the scrollshot program (see README.md) in this repo.
python3 -m venv --clear "$HOME/.local/share/scrollshot-venv" >/dev/null
"$HOME/.local/share/scrollshot-venv/bin/pip" install pillow img2pdf >/dev/null

# Enable Safari's Develop menu and "Allow JavaScript from Apple Events" (used by my scrollshot tool).
# Safari is sandboxed, so macOS only lets the terminal write its preferences if the terminal has Full Disk Access.
# Note this will quit Safari.
osascript -e 'tell application "Safari" to quit' 2>/dev/null || true
if ! {
  defaults write com.apple.Safari IncludeDevelopMenu -bool true &&
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true &&
  defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true &&
  defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true
} 2>/dev/null; then
  echo "warning: couldn't write Safari's preferences (the terminal probably lacks Full Disk Access)." >&2
  echo "Enable them manually: Safari > Settings > Advanced > 'Show features for web developers', then" >&2
  echo "Settings > Developer > 'Allow JavaScript from Apple Events'." >&2
fi

# Install my copy-reference VS Code extension (cmd+alt+c copies the selected lines as e.g. `src/main.go:12-18`, see
# README.md) from its source in this repo. VS Code only loads extensions it installed itself, so package the source as a
# .vsix (a zip with the extension under `extension/`) and install that, replacing any earlier install. Skip this if VS
# Code isn't installed.
if command -v code >/dev/null; then
  vsix_dir="$(mktemp -d)"
  mkdir "$vsix_dir/extension"
  cp "$script_dir/vscode-copy-reference/"* "$vsix_dir/extension/"
  (cd "$vsix_dir" && zip -qr copy-reference.vsix extension)
  # This prints a `url.parse()` deprecation warning (DEP0169), which is VS Code's fault: after installing, its CLI
  # always looks the extension up on the Marketplace, using a request helper that still calls `url.parse()`.
  # I cannot remove the warning, it's down to the VS Code devs to change their code.
  code --install-extension "$vsix_dir/copy-reference.vsix" --force
  rm -rf "$vsix_dir"
fi

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

# Turn off macOS's ctrl+up (Mission Control) and ctrl+down (App Exposé, i.e. the current app's windows) shortcuts, so
# the terminal can use them to jump between prompts (see config.ghostty). F3 or a four-finger swipe up still opens
# Mission Control, and a four-finger swipe down (turned on below) opens App Exposé.
#
# 32 and 33 are macOS's ids for these shortcuts. Their default keys are kept, so System Settings still shows them (65535
# = no character, key code 126 = up and 125 = down, 8650752 = ctrl plus the fn flag that arrow keys always carry). The
# values are written as XML, as the shorter `{enabled = 0; ...}` form stores them as strings, which macOS ignores.
for hotkey in '32 126' '33 125'; do
  read -r id key_code <<< "$hotkey"
  params="<integer>65535</integer><integer>$key_code</integer><integer>8650752</integer>"
  value="<dict><key>parameters</key><array>$params</array><key>type</key><string>standard</string></dict>"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    "<dict><key>enabled</key><false/><key>value</key>$value</dict>"
done
# Apply the shortcut changes now, rather than at the next login.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# Usage: `trackpad_setting <trackpad name> <global name> <type flag> <value>`
#
# Set a trackpad setting the way System Settings does, i.e. for the built-in trackpad, for a Bluetooth (Magic) trackpad,
# and in this Mac's global settings (under a different name). Written like this, it takes effect at the next login.
trackpad_setting() {
  defaults write com.apple.AppleMultitouchTrackpad "$1" "$3" "$4"
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad "$1" "$3" "$4"
  defaults -currentHost write -g "$2" "$3" "$4"
}

# Drag with three fingers (e.g. to select text or move a window), without pressing.
trackpad_setting TrackpadThreeFingerDrag com.apple.trackpad.threeFingerDragGesture -bool true
# Swipe with four fingers rather than three (2 = on, 0 = off), as three fingers now drag. Up opens Mission Control, down
# opens App Exposé, and left/right move between spaces and full-screen apps. The Dock reads the up/down ones when it
# starts, so they also take effect at the next login.
trackpad_setting TrackpadThreeFingerVertSwipeGesture com.apple.trackpad.threeFingerVertSwipeGesture -int 0
trackpad_setting TrackpadFourFingerVertSwipeGesture com.apple.trackpad.fourFingerVertSwipeGesture -int 2
trackpad_setting TrackpadThreeFingerHorizSwipeGesture com.apple.trackpad.threeFingerHorizSwipeGesture -int 0
trackpad_setting TrackpadFourFingerHorizSwipeGesture com.apple.trackpad.fourFingerHorizSwipeGesture -int 2
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
# Tap to click. It's a boolean for the trackpads but an integer globally, so it can't be set with `trackpad_setting`.
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1

# Set the other settings changed from macOS's defaults. Apps read these when they start, so they may only take effect
# once the app restarts (e.g. at the next login).
defaults write -g AppleShowAllExtensions -bool true  # Show every file's extension in Finder.
defaults write -g NSAutomaticCapitalizationEnabled -bool false  # Don't capitalise words automatically.
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false  # Don't turn two spaces into a full stop.
defaults write -g AppleKeyboardUIMode -int 2  # Tab moves between all controls in dialogs, not just text fields.
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv  # List view by default in Finder
defaults write com.apple.finder FXRemoveOldTrashItems -bool true  # Delete items from the Bin after 30 days.
defaults write com.apple.screencapture location -string '~/Downloads'  # Save screenshots to Downloads, not Desktop.
# Only show the desktop when clicking the wallpaper in Stage Manager, not normally.
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false  # No gaps between tiled windows
