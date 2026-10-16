# Record every command (and its output) with my cmdlog program (source in the cmdlog/ folder of my config repo).
# It has to sit between the terminal and zsh, so this shell replaces itself with `cmdlog record`, which starts a new zsh
# (that re-reads this file, with CMDLOG_SESSION set so it doesn't do this again). Done first, so nothing below runs twice.
# If cmdlog can't record, it starts the shell anyway (unrecorded). To stop recording, delete ~/.local/bin/cmdlog.
if [[ -o interactive && -t 0 && -t 1 && "$TERM" != dumb && -z "$CMDLOG_SESSION" ]] && (( $+commands[cmdlog] )); then
  # VS Code's shell integration script is in a temporary folder only known to this shell, so pass its location on (see cmdlog section below)
  [[ -n "$VSCODE_ZDOTDIR" ]] && export CMDLOG_VSCODE_RC="$VSCODE_ZDOTDIR/.zshrc"
  exec cmdlog record "${commands[zsh]:-/bin/zsh}"
fi

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
alias gaa='git add -u' # add tracked files (like the -a in git commit -a)
alias gad='git add .'
alias gaar='git add -u && git restore --staged'
alias gadr='git add . && git restore --staged'
alias gcd='git add . && git commit -m' # gcd stands for 'git commit directory' or 'git commit dot', as commits entire current directory (except .gitignored files)
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
    echo "fatal: must be on a branch" >&2
    return 1
  fi

  git pull origin "$branch"
}

# Resets chosen local branch to its corresponding remote branch (assumes remote source is called "origin").
# The remote branch is automatically fetched
# Usage: reset-origin <branch>
# If specified branch is current branch, uses `git reset --hard`
# If specified branch is NOT current branch, uses `git branch -f`
reset-origin() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "fatal: must explicitly supply a branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ "$target" == HEAD && -n "$current_branch" ]]; then
    target="$current_branch" # must use full branch name, not HEAD, as origin/HEAD refers to origin/main, not necessarily the intended branch
  elif [[ "$target" == HEAD ]]; then
    echo "fatal: supplied HEAD as the branch, but not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$target" || { echo "fatal: no remote branch fetched" >&2; return 1; }
  if [[ "$target" == "$current_branch" ]]; then
    git reset --hard "origin/$target"
  else
    git branch -f "$target" "origin/$target"
  fi
}

reset-main() { 
  reset-origin main
}

# Rebases current branch onto chosen remote branch (assumes remote source is called "origin").
# The remote branch is automatically fetched before the rebase
# Usage: rebase-origin <branch>
rebase-origin() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "fatal: must explicitly supply a target branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "fatal: not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$target" || { echo "fatal: no remote branch fetched" >&2; return 1; }
  git rebase "origin/$target"
}

rebase-main() { 
  rebase-origin main
}

# Merges chosen remote branch into current branch (assumes remote source is called "origin").
# The remote branch is automatically fetched before the merge
# Usage: merge-origin <branch>
merge-origin() {
  local source="$1"
  if [[ -z "$source" ]]; then
    echo "fatal: must explicitly supply a source branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "fatal: not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$source" || { echo "fatal: no remote branch fetched" >&2; return 1; }
  git merge "origin/$source"
}

merge-main() { 
  merge-origin main
}

export GH_EXPERIMENTAL_PROMPTER=1 # make gh CLI prompt inputs more natural (otherwise, sending escape sequences like alt+backspace causes crash)

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

  local tmp # temporary file with title removed, to use as PR body
  tmp=$(mktemp) || return 1
  #trap 'rm -f "$tmp"' RETURN # not valid Zsh syntax, use `always` construct instead
  {
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
  } always {
    rm -f "$tmp"
  }
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

# options for fzf's own ctrl+R shortcut to fuzzy search through shell history
# (only used if cmdlog isn't installed, as otherwise my cmdlog-history-widget replaces it - see the cmdlog section below)
export FZF_CTRL_R_OPTS="\
--with-nth=2..
--layout=default"

export BAT_THEME="Catppuccin Mocha"
eval "$(zoxide init zsh)" # after `brew install zoxide`
source <(fzf --zsh) # after `brew install fzf` and option configuration, to enable shortcuts (fzf still runnable without this)

# Custom file browser.
# Usage: browse [options] [directory]
# Output: full path to the chosen file/directory
# By default, allows multi-select (select with tab, confirm selection with enter, sent as separate lines of stdout)
# Options:
  # --group-directories-first - self explanatory.
  # --no-multi - opt out of multi-select.
# If initial directory not provided, assumes current working directory.
# From the initial directory, can interactively browse by pressing
# left to come out of the directory, right to go into the highlighted directory
browse() {
  local group=false
  local multi=true
  local directory=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group-directories-first)
        group=true
        shift
        ;;
      --no-multi)
        multi=false
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
    echo "no such directory: $directory" >&2
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

  if [[ "$multi" == true ]]; then
    FZF_OPTS+=(--multi)
  fi

  provide-contents "${PROVIDE_OPTS[@]}" "$directory" | fzf "${FZF_OPTS[@]}"
}

# alias cd so that, if no argument provided, uses my custom file browser
cd() {
  local directory="$1"
  if [[ -z "$directory" ]]; then
    builtin cd "$(browse --no-multi --group-directories-first)"
  elif [[ ! -d "$directory" ]]; then
    echo "no such directory: $directory" >&2
    return 1
  else;
    builtin cd "$directory"
  fi
}

# Custom git branch switcher that previews the log of each branch
switch() {
  local branches=$(git branch --format='%(refname:short)')
  if (($? != 0)); then
    echo 'git branch failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$branches" ]]; then
    echo "no branches found" >&2
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
    echo 'git log failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$commits" ]]; then
    echo "no commits found" >&2
    return 1
  fi

  local FZF_OPTS=( # fzf options specific to this function, in addition to FZF_DEFAULT_OPTS
    --height=100% # take up entire terminal window
    --preview="display-logs {}" # where {} injects the commit hash currently selected (can use the same program as for branches!)
    --preview-window=down,99%,sharp # make preview window take up as much horizontal and vertical space as possible
  )

  git checkout $(echo "$commits" | fzf "${FZF_OPTS[@]}")
}

## Command recording (cmdlog) ##
# See the top of this file for how cmdlog gets started.
# The hooks below print invisible "markers" telling cmdlog where each command's output starts and ends.
# Each marker contains a secret only this shell and its cmdlog know, so program output can't fake one.
# cmdlog removes the markers before passing output on to the terminal.

# Keep the secret as an unexported variable, so programs run from this shell never see it
if [[ -n "$CMDLOG_SECRET" ]]; then
  typeset -g _cmdlog_secret="$CMDLOG_SECRET"
  unset CMDLOG_SECRET
fi

if [[ -n "$_cmdlog_secret" ]]; then
  # Percent-encodes the characters that can't appear inside a marker: ';' separates its fields, BEL ends it,
  # ESC could start another escape sequence, and the terminal would turn a newline into \r\n. Result goes in $REPLY.
  _cmdlog_encode() {
    REPLY=${1//\%/%25}
    REPLY=${REPLY//;/%3B}
    REPLY=${REPLY//$'\a'/%07}
    REPLY=${REPLY//$'\e'/%1B}
    REPLY=${REPLY//$'\n'/%0A}
    REPLY=${REPLY//$'\r'/%0D}
  }

  # Runs just before each command: $1 is the command exactly as typed
  _cmdlog_preexec() {
    local REPLY dir
    _cmdlog_encode "$PWD"
    dir=$REPLY
    _cmdlog_encode "$1"
    print -rn -- $'\e]7777;'"$_cmdlog_secret;start;$dir;$REPLY"$'\a'
    _cmdlog_running=1
  }

  # Runs just before each prompt, so $? is still the exit status of the command that just finished.
  # Also runs before the first prompt, and after pressing enter on an empty line, when no command ran.
  _cmdlog_precmd() {
    local cmd_status=$?
    if (( _cmdlog_running )); then
      print -rn -- $'\e]7777;'"$_cmdlog_secret;end;$cmd_status"$'\a'
      _cmdlog_running=0
    fi
    return $cmd_status # leave $? as it was for the other precmd hooks (e.g. starship's, which shows the status)
  }

  # Put these hooks first, so the output cmdlog captures doesn't include what other hooks print
  preexec_functions=(_cmdlog_preexec ${preexec_functions:#_cmdlog_preexec})
  precmd_functions=(_cmdlog_precmd ${precmd_functions:#_cmdlog_precmd})
fi

# ctrl+r: search the recorded history (replacing fzf's own ctrl+r, set up by `source <(fzf --zsh)` above).
# Shows each distinct command once (its most recent run), and previews its directory, time, exit status and output.
# Press enter to put the command on the command line (not run it), as fzf's ctrl+r does.
if (( $+commands[cmdlog] )); then
  cmdlog-history-widget() {
    local FZF_OPTS=( # fzf options specific to this widget, in addition to FZF_DEFAULT_OPTS
      --delimiter=$'\t' # cmdlog search gives id<TAB>time<TAB>status<TAB>command
      --with-nth=2.. # hide the id
      --nth=3.. # only search the command (fields counted after --with-nth, so the 3rd shown field)
      --accept-nth=1 # only output the id
      --ansi # preserve colours
      --scheme=history
      --layout=default # newest commands nearest the command line
      --query="$LBUFFER"
      --preview='cmdlog show {1}'
      --preview-window=up,50%,sharp,wrap
      # pressing ctrl+r again toggles between all commands and only those run in the current directory (like atuin).
      # The border label shows which one is active, and doubles as the toggle's memory of it.
      # (fzf runs the transform in a new shell, in this directory. The label is set with the `:` form, as the last action,
      # so a directory name containing brackets can't break it.)
      --border-label=' all directories '
      --bind='ctrl-r:transform:if [[ $FZF_BORDER_LABEL == " all directories " ]]; then echo "reload(cmdlog search --here)+change-border-label: ${PWD/#$HOME/~} "; else echo "reload(cmdlog search)+change-border-label: all directories "; fi'
    )
    local id
    id=$(cmdlog search | fzf "${FZF_OPTS[@]}")
    if [[ -n "$id" ]]; then
      BUFFER=$(cmdlog get "$id")
      CURSOR=${#BUFFER}
    fi
    zle reset-prompt
  }
  zle -N cmdlog-history-widget
  # fzf binds ctrl+r in all three of these keymaps, so replace it in all of them (not just the current one)
  bindkey -M emacs '^R' cmdlog-history-widget
  bindkey -M viins '^R' cmdlog-history-widget
  bindkey -M vicmd '^R' cmdlog-history-widget
fi

# Ghostty and VS Code only set up their shell integration (e.g. Ghostty's click-to-move-cursor) automatically in the
# shell they start themselves, which cmdlog replaced with this one, so set it up manually here.
if [[ -n "$CMDLOG_SESSION" ]]; then
  if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
  fi
  if [[ "$TERM_PROGRAM" == vscode && -r "$CMDLOG_VSCODE_RC" && -z "$VSCODE_SHELL_INTEGRATION" ]]; then
    unset VSCODE_INJECTION # otherwise VS Code's script would source this file again
    source "$CMDLOG_VSCODE_RC"
  fi
fi

# Programs like vim can change the cursor shape and leave it changed when they exit. Ghostty's shell integration resets it
# to a line at each prompt, but VS Code's doesn't, so do that here (\e[5 q = blinking line, matching Ghostty).
if [[ "$TERM_PROGRAM" == vscode ]]; then
  _vscode_reset_cursor_precmd() {
    local cmd_status=$?
    print -n '\e[5 q'
    return $cmd_status # leave $? as it was for any later precmd hooks
  }
  precmd_functions+=(_vscode_reset_cursor_precmd)
fi

## Shortcuts to make editing the current terminal command resemble the behaviour of non-terminal text editors ##
# Coded based off either:
# the exact key sequences Ghostty & VS Code send when pressing the shortcuts at the time of writing (so far, both always agree with each other, but may not work with other terminals/configs).
# for key sequences intercepted by the app/terminal before reaching the command-line program, explicitly provided keybindings in VS Code's keybindings.json and Ghostty's config.ghostty.

WORDCHARS=${WORDCHARS//\//} # do not consider '/' as part of a word (word splitting is not impacted)
# e.g. if command populated with folder/subfolder/file123.txt, deleting word becomes folder/subfolder/

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