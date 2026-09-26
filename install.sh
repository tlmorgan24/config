#!/bin/bash
# Handy tools
brew install ripgrep # better grep - command is `rg`
brew install fd # better find
brew install eza # more visual ls
brew install bat # more user-friendly cat
brew install zoxide # better cd - command is `z` - must include `eval "$(zoxide init zsh)"` in ~/.zshrc
brew install fzf # fuzzy find - to get all capabilities, should include `source <(fzf --zsh)` in ~/.zshrc

# GNU utilities to use instead of macOS's default BSD utilities (e.g. gsed for GNU sed instead of BSD sed)
brew install gnu-sed
brew install grep
brew install findutils
brew install coreutils

brew install git

brew install --cask font-jetbrains-mono-nerd-font # my preferred font (alternative: `brew install --cask font-fira-code-nerd-font`)
brew install --cask ghostty # my preferred terminal
brew install starship # my preferred prompt customiser (i.e. to replace "user@MacBook") - powerlevel10k is an alternative, but not actively maintained
brew install --cask visual-studio-code # my preferred IDE