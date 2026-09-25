setopt interactive_comments # interpret '#' as comment, even interactively (i.e. outside scripts)

eval "$(starship init zsh)" # after `brew install starship`
eval "$(zoxide init zsh)" # after `brew install zoxide`
source <(fzf --zsh) # after `brew install fzf`, to enable Ctrl-R, Ctrl-T, and Alt-C shortcuts, and autocomplete (fzf still runnable without this)

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='pbcopy'
alias v='pbpaste'

# replace BSD with GNU, where I prefer the GNU features (must have done `brew install coreutils` first)
alias sed='gsed -E' # -E to always use extended regex, gsed to allow e.g. -i without providing a backup file
alias head='ghead' # for e.g. head -n -N file to get all except the last N lines
alias grep='ggrep -E' # -E to always use extended regex, ggrep to allow GNU-specific features (but still prefer rg most of the time)
alias find='gfind' # but still prefer fd most of the time
alias tac='gtac'

# convenient git shortcuts
alias gc='git commit -m'
alias gca='git commit -am'
alias gcd='git add . && git commit -m' # gcd stands for 'git commit directory', as commits entire current directory (except .gitignored files)
alias gcf='git commit -a --amend --no-edit' # gcf stands for 'git commit fixup', because its effect is equivalent to fixing up the previous commit
alias gci='git add . && git restore --staged .gitignore && git commit -m' # so you can locally change the .gitignore to ignore personal files without worrying about committing the gitignore itself
alias gcif='git add . && git restore --staged .gitignore && git commit --amend --no-edit'
alias push='git push origin HEAD'
alias pull='branch="$(git branch --show-current)" && [[ -n "$branch" ]] && git pull origin "$branch"' # merges current branch on origin into local branch
alias abandon='branch="$(git branch --show-current)" && [[ -n "$branch" ]] && git fetch origin "$branch" && git reset --hard origin/"$branch"' # resets HEAD to same branch on origin (i.e. discards local divergence)
alias sync='branch="$(git branch --show-current)" && [[ -n "$branch" ]] && git switch main && git pull origin main && git switch "$branch"' # merges origin/main into main (i.e. ensures main is in sync) without leaving current branch