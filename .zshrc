setopt interactive_comments # interpret '#' as comment, even interactively (i.e. outside scripts)

eval "$(starship init zsh)" # after `brew install starship`
eval "$(zoxide init zsh)" # after `brew install zoxide`
source <(fzf --zsh) # after `brew install fzf`, to enable Ctrl-R, Ctrl-T, and Alt-C shortcuts, and autocomplete (fzf still runnable without this)

## Aliases ##

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

## Shortcuts to make editing the current terminal command resemble the behaviour of other text editors ##
# Coded based off the exact key sequences Ghostty & VS Code send when pressing the shortcuts at the time of writing, so may not work with other terminals/configs.
# Ghostty config at time of writing uses macos-option-as-alt = true.

# In Ghostty & VS Code, these behaviours were already present (no need to specify in this config file):
# alt+left/right moves cursor by one word
# alt+backspace deletes previous word
# cmd+left/right moves cursor to far left/right of line
# cmd+backspace deletes whole line

# Other behaviours are specified here. Fortunately the key sequences ended up being the same for VS Code as for Ghostty,
# except that cmd+shift+left/right seems to be intercepted by VS Code before reaching Zsh - solved in VS Code's keybindings.json.
# Note, there is no way to allow deletion from mouse highlights, as Zsh does not know what the terminal has highlighted with mouse.

# shift+left: select previous character
select-backward-char() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    REGION_ACTIVE=1
    zle backward-char
}
zle -N select-backward-char
bindkey $'\e[1;2D' select-backward-char

# shift+right: select next character
select-forward-char() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    REGION_ACTIVE=1
    zle forward-char
}
zle -N select-forward-char
bindkey $'\e[1;2C' select-forward-char

# alt+shift+left: select previous word
select-backward-word() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    REGION_ACTIVE=1
    zle backward-word
}
zle -N select-backward-word
bindkey $'\e[1;4D' select-backward-word

# alt+shift+right: select next word
select-forward-word() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    REGION_ACTIVE=1
    zle forward-word
}
zle -N select-forward-word
bindkey $'\e[1;4C' select-forward-word

# cmd+shift+left: select to beginning of current line
select-backward-line() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    local line_start=${BUFFER[1,$CURSOR]##*$'\n'}
    local target=$(( CURSOR - ${#line_start} ))
    CURSOR=$target
    REGION_ACTIVE=1
}
zle -N select-backward-line
bindkey $'\e[1;10D' select-backward-line

# cmd+shift+right: select to end of current line
select-forward-line() {
    if (( ! REGION_ACTIVE )); then
        MARK=$CURSOR
    fi
    local after_cursor=${BUFFER[$((CURSOR + 1)),-1]}
    local line_end=${after_cursor%%$'\n'*}
    local target=$(( CURSOR + ${#line_end} ))
    CURSOR=$target
    REGION_ACTIVE=1
}
zle -N select-forward-line
bindkey $'\e[1;10C' select-forward-line

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

# Left after a selection: collapse the selection instead of extending it
left-or-cancel-selection() {
    if (( REGION_ACTIVE )); then
        # Collapse to the left edge of the selection
        if (( CURSOR > MARK )); then
            CURSOR=$MARK
        fi
        REGION_ACTIVE=0
        zle redisplay
    else
        zle backward-char
    fi
}
zle -N left-or-cancel-selection
bindkey $'\e[D' left-or-cancel-selection

# Right after a selection: collapse the selection instead of extending it
right-or-cancel-selection() {
    if (( REGION_ACTIVE )); then
        # Collapse to the right edge of the selection
        if (( CURSOR < MARK )); then
            CURSOR=$MARK
        fi
        REGION_ACTIVE=0
        zle redisplay
    else
        zle forward-char
    fi
}
zle -N right-or-cancel-selection
bindkey $'\e[C' right-or-cancel-selection
