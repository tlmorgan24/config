#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "fatal: this script only supports macOS." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

# Ensure Zsh is installed and set as the default shell.
if [[ ! -x /bin/zsh ]]; then
  echo "fatal: Zsh not found. This is unexpected for macOS." >&2
  exit 1
fi
if [[ "$SHELL" != /bin/zsh ]]; then
  chsh -s /bin/zsh
fi

ZPROFILE="$HOME/.zprofile"  # Best place to put PATH exports

# Install Homebrew.
if [ -x /opt/homebrew/bin/brew ]; then
  BREW="/opt/homebrew/bin/brew"
elif [ -x /usr/local/bin/brew ]; then
  BREW="/usr/local/bin/brew"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Find the newly installed Homebrew.
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW="/usr/local/bin/brew"
  else
    echo "Homebrew installation failed." >&2
    exit 1
  fi
fi

# Configure Homebrew for this session.
eval "$("$BREW" shellenv)"

# Configure Homebrew for future sessions.
BREW_SHELLENV="eval \"\$($BREW shellenv)\""
if ! grep -Fqx "$BREW_SHELLENV" "$ZPROFILE" 2>/dev/null; then
  echo "$BREW_SHELLENV" >> "$ZPROFILE"
fi

# Now, `brew` will be added to PATH, and subsequent `brew install`ed programs will also be discoverable through PATH.

# Handy tools
brew install ripgrep  # Better grep (command is `rg`)
brew install fd  # Better find
brew install eza  # More visual ls
brew install bat  # More user-friendly cat
brew install zoxide  # Smart cd to most likely directory (command is `z`), paired with `eval "$(zoxide init zsh)"` in ~/.zshrc
brew install fzf  # Fuzzy find
brew install --cask maccy  # Clipboard history

# GNU utilities to use instead of macOS's default BSD utilities (e.g. gsed for GNU sed instead of BSD sed)
brew install gnu-sed
brew install grep
brew install findutils
brew install coreutils

brew install git
brew install gh

# Programming languages
brew install go  # Used for building my cmdlog program (see copy.sh)
brew install python  # But executable is python3 (I alias it back to python in .zshrc).

# My preferred font (alternative: `brew install --cask font-fira-code-nerd-font`)
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask ghostty  # My preferred terminal
# My preferred prompt customiser (i.e. to replace "user@MacBook"). powerlevel10k is an alternative, but not actively
# maintained.
brew install starship
brew install zsh-syntax-highlighting
brew install zsh-autopair  # Auto-closes quotes and brackets as they're typed.
brew install --cask visual-studio-code  # My preferred IDE

# Install VS Code extensions (strip comments and blank lines, then install each ID). Must come after installation of VS
# Code.
sed -e 's/#.*//' -e 's/[[:space:]]//g' "$script_dir/vscode-extensions.txt" | grep . | xargs -L1 code --install-extension

# Random handy tools
brew install poppler  # For working with pdfs, e.g. merge with `pdfunite`, extract text with `pdftotext`
