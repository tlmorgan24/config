#!/bin/bash
set -euo pipefail

## ZSH ##

# Ensure Zsh is installed and set as the default shell
if [[ ! -x /bin/zsh ]]; then
  echo "fatal: Zsh not found. This is unexpected for macOS."
  exit 1
fi
if [[ "$SHELL" != /bin/zsh ]]; then
  chsh -s /bin/zsh
fi

ZPROFILE="$HOME/.zprofile" # best place to put PATH exports

## CUSTOM COMMANDS ##

# Provide accessible directory for custom commands:
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
LOCAL_PATH_EXPORT="export PATH=\"$LOCAL_BIN:\$PATH\"" # e.g. 'export PATH="/Users/thomas/.local/bin:$PATH"'
if ! grep -Fqx "$LOCAL_PATH_EXPORT" "$ZPROFILE" 2>/dev/null; then
    echo "$LOCAL_PATH_EXPORT" >> "$ZPROFILE"
fi

## HOMEBREW ##

# Install
if [ -x /opt/homebrew/bin/brew ]; then
  BREW="/opt/homebrew/bin/brew"
elif [ -x /usr/local/bin/brew ]; then
  BREW="/usr/local/bin/brew"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Find the newly installed Homebrew
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW="/usr/local/bin/brew"
  else
    echo "Homebrew installation failed."
    exit 1
  fi
fi

# Configure Homebrew for this session
eval "$("$BREW" shellenv)"

# Configure Homebrew for future sessions
BREW_SHELLENV="eval \"\$($BREW shellenv)\""
if ! grep -Fqx "$BREW_SHELLENV" "$ZPROFILE" 2>/dev/null; then
    echo "$BREW_SHELLENV" >> "$ZPROFILE"
fi

# Now, `brew` will be added to PATH, and subsequent `brew install`ed programs will also be discoverable through PATH

## INSTALLATIONS ##

# Handy tools
brew install ripgrep # better grep (command is `rg`)
brew install fd # better find
brew install eza # more visual ls
brew install bat # more user-friendly cat
brew install zoxide # better cd (command is `z`) - pair with `eval "$(zoxide init zsh)"` in ~/.zshrc
brew install fzf # fuzzy find - pair with `source <(fzf --zsh)` in ~/.zshrc

# Custom command to run for zoxide/fzf previews (see .zshrc):
cat > "$LOCAL_BIN/lsf" <<'EOF'
#!/bin/sh
# list files, packing as many as possible on each line (unlike ls and eza, which format into columns)
w="${FZF_PREVIEW_COLUMNS:-${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}}"
eza -1 --color=always "$@" | awk -v w="$w" '
  { plain=$0; gsub(/\033\[[0-9;]*m/, "", plain)
    l = length(plain) + 2
    if (len + l > w && len > 0) { print ""; len = 0 }
    printf "%s  ", $0; len += l }
  END { if (len) print "" }'
EOF
chmod +x "$LOCAL_BIN/lsf"

# GNU utilities to use instead of macOS's default BSD utilities (e.g. gsed for GNU sed instead of BSD sed)
brew install gnu-sed
brew install grep
brew install findutils
brew install coreutils

brew install git
brew install gh

brew install --cask font-jetbrains-mono-nerd-font # my preferred font (alternative: `brew install --cask font-fira-code-nerd-font`)
brew install --cask ghostty # my preferred terminal
brew install starship # my preferred prompt customiser (i.e. to replace "user@MacBook") - powerlevel10k is an alternative, but not actively maintained
brew install --cask visual-studio-code # my preferred IDE