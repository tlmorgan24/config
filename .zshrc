setopt interactive_comments # interpret '#' as comment, even interactively (i.e. outside scripts)
setopt SH_WORD_SPLIT # word splitting on whitespace, for same behaviour as Bash

# command history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY # write to history file on each command, instead of batching commands to write when shell is closed
setopt HIST_IGNORE_ALL_DUPS # discard older duplicate commands in in-memory history
setopt HIST_SAVE_NO_DUPS # discard older duplicate commands when saving to history file
setopt HIST_FIND_NO_DUPS # if, despite the above, there are still duplicates, do not show them in history search (otherwise pain to scroll back to find the command you want)

# editor
export EDITOR=vim
export VISUAL=vim

eval "$(starship init zsh)" # after `brew install starship`
zle_highlight=(default:fg=#f5e0dc) # sets colour of typed command

## Aliases ##

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='pbcopy'
alias v='pbpaste'
autoload -U zcalc # REPL calculator which removes need for `echo $((...))` whilst still being able to work with shell's variables, command substitution etc
alias calc='zcalc -f' # so, simply execute `calc` to enter the zcalc REPL calculator (Ctrl-D to exit), uses -f to make everything a float (prevent 3/4 = 0 etc)

# replace BSD with GNU, where I prefer the GNU features (must have done `brew install coreutils` first)
alias sed='gsed -E' # -E to always use extended regex, gsed to allow e.g. -i without providing a backup file
alias head='ghead' # for e.g. head -n -N file to get all except the last N lines
alias grep='ggrep -E' # -E to always use extended regex, ggrep to allow GNU-specific features (but still prefer rg most of the time)
alias find='gfind' # (but still prefer fd most of the time)
alias tac='gtac'

alias ls='eza -1 --icons=auto'
alias lst='eza -1 --tree --icons=auto'

concat() {
    printf '%s' "$@"
}
# like echo, but arguments end up joined without a space separating them
# e.g.: concat hello world --> helloworld
# whereas: echo hello world --> hello world

# convenient git shortcuts
alias gc='git commit -m'
alias gca='git commit -am'
alias gcd='git add . && git commit -m' # gcd stands for 'git commit directory', as commits entire current directory (except .gitignored files)
alias gcf='git commit --amend --no-edit' # gcf stands for 'git commit fixup', because its effect is equivalent to fixing up the previous commit
alias gci='git add . && git restore --staged .gitignore && git commit -m' # so you can locally change the .gitignore to ignore personal files without worrying about committing the gitignore itself
alias gcaf='git commit -a --amend --no-edit'
alias gcdf='git add . && git commit --amend --no-edit'
alias gcif='git add . && git restore --staged .gitignore && git commit --amend --no-edit'
alias gl='git log --oneline'
alias gt='git log --graph --oneline --all' # tree view of all commits

# pushes current branch to its upstream (if one is configured) or the same-name branch on origin (setting this as the upstream)
push() {
  if git rev-parse '@{u}' >/dev/null 2>&1; then
    git push
  else
    git push -u origin HEAD
  fi
}

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
# Usage: reset-origin <branch>
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

# Push current branch and create PR for it using provided .md file, using its level-1 header as the PR title
# Usage: pr [filepath]
# If filepath not provided, will be prompted to enter title and body manually
# The branch to merge into will be the value of gh-merge-base git branch config. If not configured, the repository's default branch (i.e. main) will be used.
pr() {
  local filepath="$1"

  if ! gh auth status >/dev/null 2>&1; then
    echo "Not authenticated - follow steps below to log in..."
    if ! gh auth login; then
      echo "Failed to authenticate. Either the login failed or you have not installed gh" >&2
      return 1
    fi
  fi

  if [[ -z "$filepath" ]]; then
    # use gh's default prompt to ask for title/body
    push || return 1
    gh pr create
    return 0
  fi

  local tmp=$(mktemp) || return 1 # temporary file with title removed, to use as PR body
  trap 'rm -f "$tmp"' RETURN

  local title=""
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == '# '* ]]; then
      if [[ -n "$title" ]]; then
        echo "fatal: multiple level-1 headers" >&2
        return 1
      fi
      title="${line#\# }"
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$filepath"

  if [[ -z "$title" ]]; then
    echo "fatal: no level-1 header found" >&2
    return 1
  fi

  push || return 1
  gh pr create -t "$title" -F "$tmp"
}

## zoxide and fzf ##

# Custom fzf configuration
export FZF_DEFAULT_OPTS="\
--border=sharp
--height=80% 
--layout=reverse
--tabstop=2
--info=hidden
--color=fg:#cdd6f4
--color=bg:#1e1e2e
--color=fg+:#cdd6f4
--color=bg+:#313244
--color=hl:#cba6f7
--color=hl+:#cba6f7
--color=prompt:#cba6f7
--color=pointer:#f38ba8
--color=marker:#a6e3a1
--color=spinner:#89dceb
--color=header:#89b4fa
--color=info:#a6adc8
--color=border:#585b70"

# Additional fzf configuration for zoxide's `zi` command.
#
# zoxide passes entries as:
#   <score> <directory>
# We hide the score from the list, and keep only the directory as the searchable/displayed field. 
# The score is still used for zoxide's ranking, which it uses to pass entries to fzf in rank order.
# --with-nth=2.. hides zoxide's score (the first field)
# --bind=start:change-nth(1) overrides zoxide's default fzf config to ensure fzf searches the new 1st field
#
# --no-sort prevents fzf from reordering the inputs based on fuzzy match score, 
# because zoxide already passes the directories in its ranked order, and
# fzf's fuzzy score reordering would not consider the original ranking.
# --exact prevents fuzzy search, i.e., must be a substring rather than subsequence. 
# This is needed because, with --no-sort, fzf will not change the ranking based on search likelihood. 
# E.g. if have folders called "Downloads" and "was", with "Downloads" ranking higher, typing "was" 
# (without --exact) would still match "Downloads" (because it still has the "was" subsequence), and 
# "Downloads" would still take priority as a match, even though "was" is unlikely to refer to "Downloads".
#
# `lsc` is my custom command for displaying the contents of the previewed directory. 
# zoxide normally uses `ls`, but its column formatting produces inconsistent spacing.
# lsc is more compact (hence the 'c')
# `{2..}` is fzf syntax for passing the second field onward (i.e. pass the directory, not the score, to lsc).
export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS
--exact
--no-sort
--cycle
--keep-right
--with-nth=2..
--bind='start:change-nth(1),ctrl-z:ignore,btab:up,tab:down'
--preview='lsc "$FZF_PREVIEW_COLUMNS" {2..}'
--preview-window=down,30%,sharp
--exit-0"

# options for ctrl+R shortcut to fuzzy search through shell history
export FZF_CTRL_R_OPTS="\
--with-nth=2..
--layout=default"

export BAT_THEME="Catppuccin Mocha"
eval "$(zoxide init zsh)" # after `brew install zoxide`
source <(fzf --zsh) # after `brew install fzf` and option configuration, to enable shortcuts (fzf still runnable without this)

# Custom file browser.
# Usage: browse [options] [directory]
# Output: full path to the chosen file/directory
# Options:
  # --group-directories-first - self explanatory.
# If initial directory not provided, assumes current working directory.
# From the initial directory, can interactively browse by pressing
# left to come out of the directory, right to go into the highlighted directory
browse() {
  local group=false
  local directory=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group-directories-first)
        group=true
        shift
        ;;
      *)
        directory="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$directory" ]]; then
    directory=$(pwd)
  elif [[ ! -d "$directory" ]]; then
    echo "browse: no such directory: $directory"
    return 1
  fi

  local PROVIDE_OPTS=()
  if [[ "$group" == true ]]; then
    PROVIDE_OPTS+=(--group-directories-first)
  fi

  local BROWSE_OPTS=()
  if [[ "$group" == true ]]; then
    BROWSE_OPTS+=(--group-directories-first)
  fi
  local BROWSE_OPTS_STR
  printf -v BROWSE_OPTS_STR '%q ' "${BROWSE_OPTS[@]}"

  local FZF_OPTS=( # fzf options specific to this browse function, in addition to FZF_DEFAULT_OPTS
    --delimiter=$'\t' # fzf is provided full_path<TAB>pretty_path fields
    --with-nth=2.. # only use the pretty path for display/search
    --accept-nth=1 # only output the full path
    --bind="right:transform(browse-in ${BROWSE_OPTS_STR} {1}),left:transform(browse-out ${BROWSE_OPTS_STR} {1})"
    --preview="display-contents {1}" # pass the full path for displaying contents
    --ansi # preserve colours
  )
  echo "$(provide-contents "${PROVIDE_OPTS[@]}" "$directory" | fzf "${FZF_OPTS[@]}")"
}

# alias cd so that, if no argument provided, uses my custom file browser
cd() {
  local directory="$1"
  if [[ -z "$directory" ]]; then
    builtin cd "$(browse --group-directories-first)"
  elif [[ ! -d "$directory" ]]; then
    echo "cd: no such directory: $directory"
    return 1
  else;
    builtin cd "$directory"
  fi
}

# Custom git branch switcher that previews the log of each branch
switch() {
  local branches=$(git branch --format='%(refname:short)')
  if (($? != 0)); then
    echo 'git branch failed: perhaps you are not in a git repository'
    return 1
  elif [[ -z "$branches" ]]; then
    echo "no branches found"
    return 1
  fi

  local FZF_OPTS=( # fzf options specific to this function, in addition to FZF_DEFAULT_OPTS
    --height=100% # take up entire terminal window
    --preview="display-logs {}" # where {} injects the branch name currently selected
    --preview-window=down,99%,sharp # make preview window take up as much horizontal and vertical space as possible
  )

  git switch $(echo "$branches" | fzf "${FZF_OPTS[@]}")
}

# Custom git checkout that previews the logs of surrounding commits
checkout() {
  local commits=$(git log --all --format='%h') # use short hashes, to exactly match the git log --oneline used in the preview
  if (($? != 0)); then
    echo 'git log failed: perhaps you are not in a git repository'
    return 1
  elif [[ -z "$commits" ]]; then
    echo "no commits found"
    return 1
  fi

  local FZF_OPTS=( # fzf options specific to this function, in addition to FZF_DEFAULT_OPTS
    --height=100% # take up entire terminal window
    --preview="display-logs {}" # where {} injects the commit hash currently selected (can use the same program as for branches!)
    --preview-window=down,99%,sharp # make preview window take up as much horizontal and vertical space as possible
  )

  git checkout $(echo "$commits" | fzf "${FZF_OPTS[@]}")
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

# shift+up: select up a line (or to the start of the command if already on the first line)
select-up-line() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  local old=$CURSOR
  zle up-line
  if (( CURSOR == old )); then
    CURSOR=0
  fi
}
zle -N select-up-line
bindkey $'\e[1;2A' select-up-line

# shift+down: select down a line (or to the end of the command if already on the last line)
select-down-line() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  local old=$CURSOR
  zle down-line
  if (( CURSOR == old )); then
    CURSOR=${#BUFFER}
  fi
}
zle -N select-down-line
bindkey $'\e[1;2B' select-down-line

# cmd+shift+up: select to beginning of the whole command
select-to-beginning-of-command() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  CURSOR=0
}
zle -N select-to-beginning-of-command
bindkey $'\e[1;10A' select-to-beginning-of-command

# cmd+shift+down: select to end of the whole command
select-to-end-of-command() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  CURSOR=${#BUFFER}
}
zle -N select-to-end-of-command
bindkey $'\e[1;10B' select-to-end-of-command

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

# alt+left: move back one word, cancelling any selection
backward-word-cancel-selection() {
  REGION_ACTIVE=0
  zle backward-word
}
zle -N backward-word-cancel-selection
bindkey $'\eb' backward-word-cancel-selection

# alt+right: move forward one word, cancelling any selection
forward-word-cancel-selection() {
  REGION_ACTIVE=0
  zle forward-word
}
zle -N forward-word-cancel-selection
bindkey $'\ef' forward-word-cancel-selection

# cmd+left: move to start of line, cancelling any selection
beginning-of-line-cancel-selection() {
  REGION_ACTIVE=0
  zle beginning-of-line
}
zle -N beginning-of-line-cancel-selection
bindkey $'^A' beginning-of-line-cancel-selection

# cmd+right: move to end of line, cancelling any selection
end-of-line-cancel-selection() {
  REGION_ACTIVE=0
  zle end-of-line
}
zle -N end-of-line-cancel-selection
bindkey $'^E' end-of-line-cancel-selection

# up: cancel any selection, then move up a line (or to the previous history entry if on the first line)
up-cancel-selection() {
  REGION_ACTIVE=0
  zle up-line-or-history
}
zle -N up-cancel-selection
bindkey $'\e[A' up-cancel-selection
bindkey $'\eOA' up-cancel-selection

# down: cancel any selection, then move down a line (or to the next history entry if on the last line)
down-cancel-selection() {
  REGION_ACTIVE=0
  zle down-line-or-history
}
zle -N down-cancel-selection
bindkey $'\e[B' down-cancel-selection
bindkey $'\eOB' down-cancel-selection

# cmd+up: move to start of the whole command (not just the current line), cancelling any selection
beginning-of-command() {
  REGION_ACTIVE=0
  CURSOR=0
}
zle -N beginning-of-command
bindkey $'\e[1;9A' beginning-of-command

# cmd+down: move to end of the whole command, cancelling any selection
end-of-command() {
  REGION_ACTIVE=0
  CURSOR=${#BUFFER}
}
zle -N end-of-command
bindkey $'\e[1;9B' end-of-command

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