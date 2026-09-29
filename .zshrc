setopt interactive_comments # interpret '#' as comment, even interactively (i.e. outside scripts)
setopt SH_WORD_SPLIT # word splitting on whitespace, for same behaviour as Bash

# command history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS # when executing duplicate command, erase older one from in-memory history (otherwise pain to scroll back through duplicates)
setopt HIST_EXPIRE_DUPS_FIRST # when history file hits size limit, remove duplicates from it before other commands

eval "$(starship init zsh)" # after `brew install starship`
eval "$(zoxide init zsh)" # after `brew install zoxide`
source <(fzf --zsh) # after `brew install fzf`, to enable Ctrl-R, Ctrl-T, and Alt-C shortcuts, and autocomplete (fzf still runnable without this)
autoload -U zcalc # REPL calculator which removes need for `echo $((...))` whilst still being able to work with shell's variables, command substitution etc

zle_highlight=(default:fg=5) # fg=i renders command foreground as palette i of terminal theme (e.g. pink in catppuccin-mocha.conf)

## Aliases ##

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='pbcopy'
alias v='pbpaste'
alias calc='zcalc -f' # so, simply execute `calc` to enter the zcalc REPL calculator (Ctrl-D to exit), uses -f to make everything a float (prevent 3/4 = 0 etc)

# replace BSD with GNU, where I prefer the GNU features (must have done `brew install coreutils` first)
alias sed='gsed -E' # -E to always use extended regex, gsed to allow e.g. -i without providing a backup file
alias head='ghead' # for e.g. head -n -N file to get all except the last N lines
alias grep='ggrep -E' # -E to always use extended regex, ggrep to allow GNU-specific features (but still prefer rg most of the time)
alias find='gfind' # (but still prefer fd most of the time)
alias tac='gtac'

# convenient git shortcuts
alias gc='git commit -m'
alias gca='git commit -am'
alias gcd='git add . && git commit -m' # gcd stands for 'git commit directory', as commits entire current directory (except .gitignored files)
alias gcf='git commit -a --amend --no-edit' # gcf stands for 'git commit fixup', because its effect is equivalent to fixing up the previous commit
alias gci='git add . && git restore --staged .gitignore && git commit -m' # so you can locally change the .gitignore to ignore personal files without worrying about committing the gitignore itself
alias gcif='git add . && git restore --staged .gitignore && git commit --amend --no-edit'
alias gl='git log --oneline'
alias push='git push origin HEAD'

# merges current branch's remote into local (assuming remote source is called "origin")
pull() {
  local branch="$(git branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "Must be on a branch"
    return 1
  fi

  git pull origin "$branch"
}

# Resets chosen local branch to its corresponding remote branch (assumes remote source is called "origin").
# If specified branch is current branch, uses `git reset --hard`
# If specified branch is NOT current branch, uses `git branch -f`
reset-origin() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "fatal: must explicitly supply a branch"
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ "$target" == HEAD && -n "$current_branch" ]]; then
    target="$current_branch" # must use full branch name, not HEAD, as origin/HEAD refers to origin/main, not necessarily the intended branch
  elif [[ "$target" == HEAD ]]; then
    echo "fatal: supplied HEAD as the branch, but not currently on any branch"
    return 1
  fi;

  git fetch origin "$target" || { echo "fatal: remote branch not found"; return 1; }
  if [[ "$target" == "$current_branch" ]]; then
    git reset --hard "origin/$target"
  else
    git branch -f "$target" "origin/$target"
  fi
}

reset-main() { 
  reset-origin main
}

## Shortcuts to make editing the current terminal command resemble the behaviour of non-terminal text editors ##
# Coded based off either:
# the exact key sequences Ghostty & VS Code send when pressing the shortcuts at the time of writing (so far, both always agree with each other, but may not work with other terminals/configs).
# for key sequences intercepted by the app/terminal before reaching the command-line program, explicitly provided keybindings in VS Code's keybindings.json and Ghostty's config.ghostty.

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

# helper
delete-active-selection() {
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
}

# Backspace: delete selection if there is one, otherwise delete previous character
delete-selection-or-backspace() {
  if (( REGION_ACTIVE )); then
    delete-active-selection
    zle redisplay
  else
    zle backward-delete-char
  fi
}
zle -N delete-selection-or-backspace
bindkey '^?' delete-selection-or-backspace

# Typing: delete selection if there is one, then insert the typed character
self-insert-or-replace-selection() {
  if (( REGION_ACTIVE )); then
    delete-active-selection
  fi
  zle self-insert
}
zle -N self-insert-or-replace-selection
bindkey -R ' '-'~' self-insert-or-replace-selection # printable ASCII characters

# Left: collapse the selection if there is one, otherwise move cursor left by one character
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

# Right: collapse the selection if there is one, otherwise move cursor right by one character
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

# cmd+backspace: delete from cursor to beginning of current line (regardless of active selection)
delete-backward-line() {
  local line_start=${BUFFER[1,$CURSOR]##*$'\n'}
  local count=${#line_start}
  if (( count > 0 )); then
    BUFFER="${BUFFER[1,$((CURSOR-count))]}${BUFFER[$((CURSOR+1)),-1]}"
    CURSOR=$((CURSOR-count))
  fi
}
zle -N delete-backward-line
bindkey $'^U' delete-backward-line

# cmd+c: copy active selection to clipboard
# in Ghostty / VS Code, I actually only send if press cmd+shift+c, because cmd+c is already used by them to mean copy TERMINAL's selection (e.g. following mouse drag) rather than ZSH's
copy-selection-to-clipboard() {
  if (( REGION_ACTIVE )); then
    local start=$MARK
    local end=$CURSOR

    if (( start > end )); then
      local tmp=$start
      start=$end
      end=$tmp
    fi

    print -rn -- "${BUFFER[start+1,end]}" | pbcopy
  fi
}
zle -N copy-selection-to-clipboard
bindkey $'\e[99;9u' copy-selection-to-clipboard

# cmd+x: cut active selection to clipboard
cut-selection-to-clipboard() {
  if (( REGION_ACTIVE )); then
    local start=$MARK
    local end=$CURSOR

    if (( start > end )); then
      local tmp=$start
      start=$end
      end=$tmp
    fi

    print -rn -- "${BUFFER[start+1,end]}" | pbcopy

    BUFFER="${BUFFER[1,start]}${BUFFER[end+1,-1]}"
    CURSOR=$start
    REGION_ACTIVE=0
  fi
}
zle -N cut-selection-to-clipboard
bindkey $'\e[120;9u' cut-selection-to-clipboard

# undo/redo
#bindkey '^_' undo # commented out as undo is already the response to '^_'
bindkey '^[/' redo