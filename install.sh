#!/bin/bash
# Installs all relevant tools
brew install ripgrep # better grep - command is `rg`
brew install fd # better find
brew install eza # better ls
brew install bat # better cat
brew install zoxide # better cd - command is `z` - must include `eval "$(zoxide init zsh)"` in ~/.zshrc
brew install fzf # fuzzy find - to get all capabilities, should include `source <(fzf --zsh)` in ~/.zshrc
brew install coreutils # GNU rather than macOS's BSD utilities (can then use e.g. gsed for GNU sed instead of BSD sed)
brew install --cask font-jetbrains-mono-nerd-font # my preferred font (alternative: `brew install --cask font-fira-code-nerd-font`)
brew install --cask ghostty # my preferred terminal
brew install starship # my preferred prompt customiser (i.e. to replace "user@MacBook") - powerlevel10k is an alternative, but not actively maintained
brew install --cask visual-studio-code # my preferred IDE