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

# shortcuts to make editing your current terminal command more similar to other apps
# cmd+backspace already deletes whole line in Ghostty
# alt+backspace already deletes previous word in Ghostty (and default macOS terminal)

# alt+shift+left: select previous word
select-backward-word() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi

    REGION_ACTIVE=1
    zle backward-word
}

# alt+shift+right: select next word
select-forward-word() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi

    REGION_ACTIVE=1
    zle forward-word
}

zle -N select-backward-word
zle -N select-forward-word

bindkey $'\e[1;4D' select-backward-word
bindkey $'\e[1;4C' select-forward-word

# Delete active selection with backspace:
delete-selection-or-backspace() {
    if (( REGION_ACTIVE )); then
        local start=$MARK
        local end=$CURSOR

        if (( start > end )); then
            local tmp=$start
            start=$end
            end=$tmp
        fi

        BUFFER="${BUFFER[1,start]}${BUFFER[end+1,-1]}"
        CURSOR=$start
        REGION_ACTIVE=0
    else
        zle backward-delete-char
    fi
}

zle -N delete-selection-or-backspace

bindkey '^?' delete-selection-or-backspace
