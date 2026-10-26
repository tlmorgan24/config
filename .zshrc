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
setopt EXTENDED_GLOB

# Freeze terminal modes, so zsh puts them back after every command instead of keeping whatever a command left behind.
# E.g. in `head -n 10 $(fzf) | bat`, fzf and less run at the same time: less saves fzf's raw mode as the mode to restore,
# so after it exits every later command's output stair-steps (no carriage return after newlines) and ctrl+c stops working.
# To change modes on purpose: `ttyctl -u; stty ...; ttyctl -f`
ttyctl -f

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

## Aliases ##

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='pbcopy'
alias v='pbpaste'
autoload -U zcalc # REPL calculator which removes need for `echo $((...))` whilst still being able to work with shell's variables, command substitution etc
alias calc='zcalc -f' # so, simply execute `calc` to enter the zcalc REPL calculator (Ctrl-D to exit), uses -f to make everything a float (prevent 3/4 = 0 etc)

# cd with automatic mkdir.
mkcd() {
  mkdir -p "$1" && cd "$1"
}
# Directory that mkcp/mkmv must create, given the command (cp or mv) and its args, same rule as cp/mv themselves:
# with GNU's -t DIR it's DIR, otherwise the destination (last operand) is a directory if it ends in / or there are
# multiple sources, else it's a file path, so take its parent.
# Flags are passed through to cp/mv, so aren't counted as operands, and nor are flag values. GNU's -t/--target-directory
# and -S/--suffix take a value, but no BSD flag does (BSD cp has an unrelated -S that takes none), hence checking which we have.
_mkdestdir() {
  local cmd=$1; shift
  local gnu=0
  command $cmd --version &>/dev/null && gnu=1 # BSD rejects --version
  local -a operands
  local arg name val target i
  for (( i = 1; i <= $#; i++ )); do
    arg="${@[i]}"
    if [[ "$arg" == -- ]]; then
      operands+=("${@[i+1,-1]}")
      break
    elif [[ "$arg" != -?* ]]; then
      operands+=("$arg")
    elif (( ! gnu )); then
      continue
    elif [[ "$arg" == --* ]]; then
      # GNU accepts any unambiguous prefix of a long option, e.g. --target for --target-directory
      name="${arg%%=*}"
      if (( ${#name} >= 3 )) && [[ --target-directory == "$name"* ]]; then
        if [[ "$arg" == *=* ]]; then target="${arg#*=}"; else target="${@[++i]}"; fi
      elif (( ${#name} >= 4 )) && [[ --suffix == "$name"* && "$arg" != *=* ]]; then
        (( i++ ))
      fi
    elif [[ "$arg" =~ '^-[^tS]*([tS])(.*)$' ]]; then
      # short flags can be bundled, and the value attached, e.g. -vt DIR or -vtDIR
      val="${match[2]}"
      [[ -z "$val" ]] && val="${@[++i]}"
      [[ "${match[1]}" == t ]] && target="$val"
    fi
  done
  if [[ -n "$target" ]]; then
    print -r -- "$target"
  elif [[ "${operands[-1]}" == */ ]] || (( ${#operands} > 2 )); then
    print -r -- "${operands[-1]}"
  else
    print -r -- "${operands[-1]:h}"
  fi
}
# Runs cp or mv ($1) on the remaining args, first creating the directory they need. If the command fails, the
# directories this created are removed again, but only while empty (rmdir), so anything it did manage to copy/move stays.
_mkrun() {
  local cmd=$1; shift
  local dir="$(_mkdestdir $cmd "$@")"
  local -a created # deepest first, so rmdir empties each one's parent before reaching it
  local d="$dir"
  while [[ ! -e "$d" ]]; do
    created+=("$d")
    d="${d:h}"
  done
  mkdir -p -- "$dir" || return
  command $cmd "$@" && return
  local ret=$?
  (( ${#created} )) && rmdir -- "${created[@]}" 2>/dev/null
  return $ret
}
# cp with automatic mkdir.
mkcp() {
  (( $# >= 2 )) || { echo 'usage: mkcp [flags] source... destination' >&2; return 1 }
  _mkrun cp "$@"
}
# mv with automatic mkdir.
mkmv() {
  (( $# >= 2 )) || { echo 'usage: mkmv [flags] source... destination' >&2; return 1 }
  _mkrun mv "$@"
}
# Creates the parent directory of file path $1, then prints the path.
# Useful for redirecting to with automatic mkdir,  e.g. cmd > "$(mkp out/sub/file)".
mkp() {
  (( $# == 1 )) || { echo 'usage: mkp path' >&2; return 1 }
  mkdir -p -- "${1:h}" && print -r -- "$1"
}

# replace BSD with GNU, where I prefer the GNU features (must have done `brew install coreutils` first)
alias sed='gsed -E' # -E to always use extended regex, gsed to allow e.g. -i without providing a backup file
alias head='ghead' # for e.g. head -n -N file to get all except the last N lines
alias grep='ggrep -E' # -E to always use extended regex, ggrep to allow GNU-specific features (but still prefer rg most of the time)
alias find='gfind' # (but still prefer fd most of the time)
alias tac='gtac'

alias ls='eza -1 --icons=auto'
alias lst='eza -1 --tree --icons=auto'

alias rg='rg -P' # -P to always use PCRE (maximal regex features)
# Note fd does not support this, but still has most features except backreferences & lookarounds

# Alias for perl -ane, while still allowing extra flags to be passed without -e swallowing them.
# Note, can still provide -p as a flag (effectively overwrites -n).
#
# Also takes -R<sep> for a custom record separator, acting as the record counterpart of -F:
# <sep> is always a perl regex, optionally written /like this/, so e.g. a literal | is -R'\|'.
# It must not be able to match the empty string, and can't be combined with -0 (or used by pp).
#
# A separator with no regex metacharacters just uses perl's own $/; anything else is extra custom work,
# as not supported by Perl. Neither loads whole files into memory. Both end up with $., eof, -p, etc
# working as expected.
#
# With -R, $_ keeps its separator unless -l is given. With -l, the separator is stripped from $_
# and put back by every print (including -p's). This is the exact matched separator the record had, or
# nothing for a final unterminated record. In END blocks, -l prints end in "\n" instead.
p() {
  local -a args=() flags=()
  local rs= has_rs=0 has_0=0 regex=0 fs= nl=0 inplace= ip=0 b plain c
  while [[ $1 == -* ]]; do
    [[ $1 == -- ]] && { shift; break; }
    args+=("$1")
    # Split a switch bundle the way perl does: argless switches combine, and a switch
    # that takes a value (-i, -F, -e, -M, ...) uses up the rest of the bundle.
    b=${1#-} plain=
    while [[ -n $b ]]; do
      c=${b:0:1}; b=${b:1}
      case $c in
        R) has_rs=1; rs=$b; b= ;;
        0) has_0=1; [[ $b =~ ^(x[[:xdigit:]]*|[0-7]*) ]] && b=${b:${#MATCH}} ;;
        l) nl=1; [[ $b =~ ^[0-7]* ]] && b=${b:${#MATCH}} ;;
        a) ;;
        i) ip=1; inplace=$b; b= ;;
        F) fs=$b; b= ;;
        [npscSTtUuWwX]) plain+=$c ;;
        *) flags+=("-$c$b"); b= ;;
      esac
    done
    [[ -n $plain ]] && flags+=("-$plain")
    shift
  done
  if ((!has_rs)); then
    perl -an "${args[@]}" -e "$1" "${@:2}"
    return
  fi

  ((has_0)) && { echo "p: -R can't be combined with -0" >&2; return 2; }
  [[ $rs == /*/ && ${#rs} -ge 2 ]] && rs=${rs:1:${#rs}-2}
  [[ -z $rs ]] && { echo "p: -R separator can't be empty" >&2; return 2; }
  [[ $rs =~ '[][\\^$.|?*+(){}]' ]] && regex=1
  if ((ip)); then
    if ((regex)); then [[ -z $inplace ]] && inplace=.prs$$
    else flags+=("-i$inplace"); inplace=; fi
  fi
  local split='our @F = length $PRS::FS ? split(/$PRS::FS/) : split(" ");'
  local endfix=';END { $\ = "\n" if $ENV{PRS_L}; select STDOUT }' # runs before user END blocks

  if ((!regex)); then
    PRS_RS=$rs PRS_FS=$fs PRS_L=$nl perl -n "${flags[@]}" -e '
BEGIN { $/ = $ENV{PRS_RS}; ($PRS::FS = $ENV{PRS_FS}) =~ s{^/(.*)/$}{$1}s }
if ($ENV{PRS_L}) { my $o = $_; chomp; $\ = substr $o, length } # put back exactly what chomp removed
'"$split" -e "$1" -e "$endfix" "${@:2}"
    return
  fi

  PRS_RS=$rs PRS_FS=$fs PRS_L=$nl PRS_I=$inplace PRS_IKEEP=${inplace:+$([[ $inplace == .prs$$ ]] || echo 1)} \
  perl -n -Mopen=IN,':via(PRS)' "${flags[@]}" -e '
BEGIN {
  package PRS;
  our $S = "\x{1E}PRS\x{1E}"; # sentinel that becomes $/
  our $RS = qr/$ENV{PRS_RS}/;
  if ("" =~ $RS) { warn "p: separator /$ENV{PRS_RS}/ can match the empty string\n"; exit 2 }
  ($PRS::FS = $ENV{PRS_FS}) =~ s{^/(.*)/$}{$1}s;
  # A flush (which perl does to every handle before system, fork, etc) drops whatever is left of
  # the result of the last FILL, so FILL hands out one record at a time and nothing is left over.
  sub PUSHED { bless ["", []], shift } # [unscanned input, marked records waiting to be handed out]
  sub FILL { # mark separators; hold back incomplete tail
    my ($self, $fh) = @_;
    my ($buf, $q) = (\$self->[0], $self->[1]);
    while (1) {
      return shift @$q if @$q;
      my $n = read $fh, my $chunk, 65536;
      $$buf .= $chunk if $n;
      my $at_eof = !$n;
      my $keep = 0;
      while ($$buf =~ /\G(.*?)($RS)/gcs) {
        my ($rec, $sep) = ($1, $2);
        last if !$at_eof && $+[0] >= length $$buf; # match might extend further
        last if !length $sep; # ignore empty matches
        push @$q, $rec . $sep . "\0" . length($sep) . $S;
        $keep = $+[0];
      }
      substr($$buf, 0, $keep) = "";
      if ($at_eof && length $$buf) { push @$q, $$buf; $$buf = "" }
      return undef if $at_eof && !@$q;
    }
  }
  # stdin must be opened by name so the layer applies
  @ARGV = ("-") unless @ARGV;
  our %name;
  for (@ARGV) { if ($_ eq "-") { $_ = "/dev/stdin"; $name{$_} = "-" } }
  # -i emulation: read from a renamed copy, write to the original name
  our ($I, @tmp) = ($ENV{PRS_I});
  if (length $I) {
    for (@ARGV) {
      next if exists $name{$_};
      my $orig = $_; my $bak = "$orig$I";
      rename $orig, $bak or die "p: cannot rename $orig: $!\n";
      push @tmp, $bak unless $ENV{PRS_IKEEP};
      $name{$bak} = $orig; $_ = $bak;
    }
  }
  our $cur = "";
  END { unlink @PRS::tmp }
  $/ = $S;
}
if ($ARGV ne $PRS::cur) {
  my $real = $ARGV;
  $PRS::cur = $ARGV = $PRS::name{$real} // $real;
  if (length $PRS::I && $ARGV ne "-") {
    open PRS::OUT, ">", $ARGV or die "p: cannot write $ARGV: $!\n";
    chmod((stat $real)[2] & 07777, $ARGV);
    select PRS::OUT;
  }
}
if (s/\0(\d+)\Q$PRS::S\E\z//) { $\ = substr($_, -$1, $1, "") if $ENV{PRS_L} }
elsif ($ENV{PRS_L}) { $\ = "" } # final record had no separator, so nothing to put back
'"$split" -e "$1" -e "$endfix" "${@:2}"
}

# Like p, but slurps the whole input as one record (-0777).
pp() { p -0777 "$@"; }

# ff - stands for "For each File" or "For each output of Fd"
# Like fd -x, but runs arbitrary shell code for each file found, with the path in $f.
#   ff [fd args] <code>
# The code comes last, everything before it goes to fd. Single-quote the code so 
# treated as one argument and so shell does not expand $f before it reaches the function. 
# And, double-quote the $f as normal if want to avoid word splitting.
# E.g. `ff -e md 'echo "$f"; head -1 "$f"'`
# Runs in the current shell (aliases, functions and variables all work), reading fd's output from fd 3
# so commands in the code that read stdin don't swallow the file list.
ff() {
  local cmd=${@[-1]} f
  while IFS= read -r -d '' f <&3; do eval "$cmd"; done 3< <(fd -0 "${@[1,-2]}")
}

# fr - stands for "For each Record"
# Like ff, but for records split on a regex (via p -R), with the record in $r and the exact
# separator that ended it in $s (empty for a final unterminated record).
#   fr <sep> <code> [files]
# <sep> is anything p -R takes, e.g. '\n\n+' or /,\s*/. Reads stdin if no files are given.
# E.g. `printf 'a,b,c' | fr , 'echo "item: $r"'`
# Same quoting rules and current-shell behaviour as ff. Records containing NUL bytes get split there.
fr() {
  local sep=$1 cmd=$2 r s; shift 2
  while IFS= read -r -d '' r <&3 && IFS= read -r -d '' s <&3; do eval "$cmd"; done \
    3< <(p -l -R"$sep" 'printf "%s\0%s\0", $_, $\' "$@")
}

# fl - stands for "For each Line"
# fr with a newline separator, so the line is in $r ($s is a newline, or empty for an unterminated last line).
#   fl <code> [files]
# E.g. `fl 'mkdir "$r"' names.txt`
# A literal newline (rather than '\n') lets p use perl's own $/, skipping the slower regex splitting.
fl() { fr $'\n' "$@"; }

# Like echo, but arguments end up joined without a space separating them.
# E.g. `concat hello world` --> helloworld
# whereas `echo hello world` --> hello world
concat() {
    printf '%s' "$@"
}

alias python='python3'

# govi - quickly run a draft Go program: mkcd into the directory, init a module there, create boilerplate main.go to edit in vim, then automatically format, tidy modules and run.
#   govi [directory [module name]]
# The directory defaults to CWD (pass "" to give a module name without changing directory) and the module name defaults to draft.
# Refuses to run if main.go already exists in the directory, so an existing program isn't overwritten.
# Vim opens on the Println line. Quit with :cq to skip formatting and running (loses unsaved changes).
govi() {
  _goinit govi "$@" && vim +6 main.go && go fmt && go mod tidy && go run .
}
# goco - like govi, but opens the directory in VS Code for more in-depth work, and doesn't run anything.
goco() {
  _goinit goco "$@" && code . -g main.go:6
}
# Shared setup for govi and goco: mkcd, init the module and create main.go. First argument is the caller's name, for errors.
_goinit() {
  local name=$1; shift
  local dir="${1:-.}"
  if [[ -e "$dir/main.go" ]]; then
    echo "$name: $dir/main.go already exists" >&2
    return 1
  fi
  mkcd "$dir" && go mod init "${2:-draft}" &&
    printf 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, world!")\n}\n' > main.go
}

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
    echo "pull: must be on a branch" >&2
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
    echo "reset-origin: must explicitly supply a branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ "$target" == HEAD && -n "$current_branch" ]]; then
    target="$current_branch" # must use full branch name, not HEAD, as origin/HEAD refers to origin/main, not necessarily the intended branch
  elif [[ "$target" == HEAD ]]; then
    echo "reset-origin: supplied HEAD as the branch, but not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$target" || { echo "reset-origin: no remote branch fetched" >&2; return 1; }
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
    echo "rebase-origin: must explicitly supply a target branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "rebase-origin: not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$target" || { echo "rebase-origin: no remote branch fetched" >&2; return 1; }
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
    echo "merge-origin: must explicitly supply a source branch" >&2
    return 1
  fi;
  
  local current_branch="$(git branch --show-current)" # empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "merge-origin: not currently on any branch" >&2
    return 1
  fi;

  git fetch origin "$source" || { echo "merge-origin: no remote branch fetched" >&2; return 1; }
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
      echo "pr: failed to authenticate. Either the login failed or you have not installed gh" >&2
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
          echo "pr: multiple level-1 headers" >&2
          return 1
        fi
        title="${line#\# }"
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$filepath"

    if [[ -z "$title" ]]; then
      echo "pr: no level-1 header found" >&2
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
    echo "browse: no such directory: $directory" >&2
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
  if (($# == 0)); then
    builtin cd "$(browse --no-multi --group-directories-first)"
  else
    builtin cd "$@" # pass through so special arguments like `-`, `-2` and `-P` still work
  fi
}

# Custom git branch switcher that previews the log of each branch
switch() {
  local branches=$(git branch --format='%(refname:short)')
  if (($? != 0)); then
    echo 'switch: git branch failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$branches" ]]; then
    echo "switch: no branches found" >&2
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
    echo 'checkout: git log failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$commits" ]]; then
    echo "checkout: no commits found" >&2
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

## Auto-pairing quotes and brackets ##

# Auto-pair quotes and brackets (typing " inserts "", typing the closing " skips over it, backspace between "" deletes both),
# after `brew install zsh-autopair`. It normally binds those keys (and backspace) itself, which would replace the
# selection-aware typing/backspace widgets below, so stop it binding anything and call its widgets from those instead.
# Its fallback widgets are set to zle's own, since mine (which would otherwise be picked up) call autopair's.
AUTOPAIR_INHIBIT_INIT=1
AUTOPAIR_SPC_WIDGET=self-insert
AUTOPAIR_BKSPC_WIDGET=backward-delete-char
source /opt/homebrew/share/zsh-autopair/autopair.zsh
zle -N autopair-insert
zle -N autopair-close
zle -N autopair-delete

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
    zle autopair-delete # backward-delete-char, but also deletes the closing half of an empty pair, e.g. "|"
  fi
}
zle -N delete-selection-or-backspace
bindkey '^?' delete-selection-or-backspace

# Typing: delete selection if there is one, then insert the typed character (auto-paired, if it's a quote or bracket)
self-insert-or-replace-selection() {
  # autopair is written for zsh's default word splitting, and SH_WORD_SPLIT (set at the top) would make it drop a typed space
  setopt local_options no_sh_word_split
  if (( REGION_ACTIVE )); then
    delete-active-selection
  fi
  if [[ -n ${AUTOPAIR_PAIRS[$KEYS]} ]]; then
    zle autopair-insert # opening character (quotes, brackets, and space - which pairs to { | } inside brackets)
  elif (( ${${(v)AUTOPAIR_PAIRS}[(Ie)$KEYS]} )); then
    zle autopair-close # closing bracket
  else
    zle self-insert
  fi
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

## Syntax highlighting of the command being typed ##

zle_highlight=('default:fg=#cdd6f4') # Zsh default colour (fallback for anything zsh-syntax-highlighting doesn't colour)
# After `brew install zsh-syntax-highlighting`. Must stay at the very end of this file (its docs require it to be sourced
# after everything else that defines zle widgets).
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Colours are from the Catppuccin Mocha palette, assigned as per Catppuccin's style guide
# (https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md).
# Defaults
ZSH_HIGHLIGHT_STYLES[default]='fg=#cdd6f4' # text: positional arguments etc
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#cdd6f4' # text: command names the styles below don't cover
# Commands: blue (the guide's colour for functions)
ZSH_HIGHLIGHT_STYLES[command]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[function]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#89b4fa,italic' # sudo, exec, etc
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#fab387,italic' # peach: a directory typed as a command (to cd into it)
# Control flow: mauve (the guide's colour for keywords)
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#cba6f7' # if, for, do, etc
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#cba6f7' # | ; && || - these join commands, much like then/do, so they're not sky like operators
# Options
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#fab387' # peach
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#fab387' # peach
# Operators: sky
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#89dceb' # > < >> etc
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#fab387' # peach (numbers): the 2 in 2>&1
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#cdd6f4' # text: the fd in {fd}>file
# Strings: green
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#a6e3a1' # $'...'
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#a6e3a1' # "$(command)"
# Variables: rosewater (the guide's colour for macros, which like variables get replaced by something else before running)
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#f5e0dc' # $var inside "..."
ZSH_HIGHLIGHT_STYLES[parameter]='fg=#f5e0dc' # $var elsewhere (used by my parameter and arithmetic highlighters below)
# Escape sequences and patterns: pink
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#f5c2e7' # \" \$ etc inside "..."
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#f5c2e7' # \n \t etc inside $'...'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#f5c2e7' # '' inside '...' (with the RC_QUOTES option)
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#f5c2e7' # * ? [...]
# Delimiters: overlay 2
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#9399b2' # the ` ` around `command`
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#9399b2' # the $( ) around $(command)
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#9399b2' # the $( ) around $(command) in an unquoted argument
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#9399b2' # the $( ) around "$(command)"
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#9399b2' # the <( ) around <(command)
# Paths: text, underlined
ZSH_HIGHLIGHT_STYLES[path]='fg=#cdd6f4,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#cdd6f4,underline' # a path that's still being typed
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#cba6f7,underline' # mauve: the / in paths
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#cba6f7,underline' # mauve: the / in paths for a path that's still being typed
# Arithmetic, i.e. inside (( )) and $(( )). Only the arithmetic-expansion style is the plugin's (which it applies to a whole
# $(( ))); the others are used by my arithmetic highlighter below. arithmetic-expansion must stay "none", as that highlighter
# finds the $(( ))s by it
ZSH_HIGHLIGHT_STYLES[arithmetic-expansion]='none'
ZSH_HIGHLIGHT_STYLES[arithmetic-delimiter]='fg=#9399b2' # overlay 2: the $(( )) around $((1 + 1)) ((( )) are reserved-words)
ZSH_HIGHLIGHT_STYLES[arithmetic-bracket]='fg=#9399b2' # overlay 2
ZSH_HIGHLIGHT_STYLES[arithmetic-operator]='fg=#89dceb' # sky: + - * / == etc
ZSH_HIGHLIGHT_STYLES[arithmetic-number]='fg=#fab387' # peach
# Other
ZSH_HIGHLIGHT_STYLES[assign]='fg=#cdd6f4' # text: var=value
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#cba6f7' # mauve: !! !$ etc
ZSH_HIGHLIGHT_STYLES[comment]='fg=#9399b2' # overlay 2
# Errors: red
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8' # e.g. a command that doesn't exist
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#f38ba8'

# Underline quoted paths too. zsh-syntax-highlighting recognises "/etc/hosts" as a path, but colours it as a string afterwards,
# which replaces the path's underline rather than adding to it. This highlighter runs straight after the main one and redraws
# any part of a path that was recoloured (e.g. a quoted string) in that colour plus underline.
# It reads the main highlighter's results from the plugin's internal (undocumented) cache variable, so a plugin upgrade could
# stop it working - in which case quoted paths just aren't underlined.
# Tested with zsh-syntax-highlighting 0.8.0 and zsh 5.9 (zsh controls the "start end style" format of the cached entries).
# If an upgrade breaks it, go back to 0.8.0 and `brew pin zsh-syntax-highlighting`.
_zsh_highlight_highlighter_pathunderline_predicate() { _zsh_highlight_highlighter_main_predicate }
_zsh_highlight_highlighter_pathunderline_paint() {
  emulate -L zsh
  local entry
  local -a fields paths
  for entry in $_zsh_highlight__highlighter_main_cache; do # entries are "start end style ..."
    fields=(${(s: :)entry})
    if [[ ${fields[3]%,} == ($ZSH_HIGHLIGHT_STYLES[path]|$ZSH_HIGHLIGHT_STYLES[path_prefix]) ]]; then
      paths+=($fields[1] $fields[2])
    fi
  done
  (( $#paths )) || return
  local -i i
  local -a separators
  for entry in $_zsh_highlight__highlighter_main_cache; do
    fields=(${(s: :)entry})
    for (( i = 1; i < $#paths; i += 2 )); do
      if (( fields[1] >= paths[i] && fields[2] <= paths[i+1] )); then
        if [[ ${fields[3]%,} == ($ZSH_HIGHLIGHT_STYLES[path_pathseparator]|$ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]) ]]; then
          separators+=("$fields[1] $fields[2] ${fields[3]%,}, memo=zsh-syntax-highlighting")
        elif [[ $fields[3] != *underline* ]]; then
          region_highlight+=("$fields[1] $fields[2] ${fields[3]%,},underline, memo=zsh-syntax-highlighting")
        fi
        break
      fi
    done
  done
  # Re-add the /s' own highlights last, as the redrawn strings above would otherwise cover them
  region_highlight+=($separators)
}

# Colour the insides of (( )) and $(( )) (numbers, operators, etc), which zsh-syntax-highlighting leaves uncoloured. Like the
# pathunderline highlighter, this runs after the main one and relies on its cache: it finds (( )) commands by their (( and ))
# entries, and $(( )) expansions by their arithmetic-expansion entries, then colours what's between
_zsh_highlight_highlighter_arithmetic_predicate() { _zsh_highlight_highlighter_main_predicate }
_zsh_highlight_highlighter_arithmetic_paint() {
  emulate -L zsh
  local entry
  local -a fields opens closes
  local -A expansions # start -> finish
  for entry in $_zsh_highlight__highlighter_main_cache; do # entries are "start end style ..."
    fields=(${(s: :)entry})
    case $BUFFER[fields[1]+1,fields[2]] in
      ('((') opens+=($fields[1]) ;; # a (( )) command, including in a for loop
      ('))') closes+=($fields[1]) ;;
      ('$(('*) # a $(( )) expansion. If another entry starts at the same place, it's for a longer argument that the expansion is
        # only the start of
        if [[ $fields[3] == $ZSH_HIGHLIGHT_STYLES[arithmetic-expansion], ]] &&
           (( ! $+expansions[$fields[1]] || fields[2] < expansions[$fields[1]] )); then
          expansions[$fields[1]]=$fields[2]
        fi ;;
    esac
  done
  local -i start finish close
  for start in ${(u)opens}; do
    finish=-1
    for close in ${(n)closes}; do (( close > start )) && { finish=$close; break }; done
    _zsh_highlight_add_highlight $start $(( start + 2 )) reserved-word # as the main highlighter doesn't for a for loop's ((
    if (( finish < 0 )); then
      _zsh_highlight_arithmetic_contents $(( start + 3 )) $#BUFFER # unclosed, so its contents run to the end of the line
    else
      _zsh_highlight_add_highlight $finish $(( finish + 2 )) reserved-word
      _zsh_highlight_arithmetic_contents $(( start + 3 )) $finish
    fi
  done
  for start finish in ${(kv)expansions}; do
    _zsh_highlight_add_highlight $start $(( start + 3 )) arithmetic-delimiter
    if [[ $BUFFER[finish-1,finish] == '))' ]]; then
      _zsh_highlight_add_highlight $(( finish - 2 )) $finish arithmetic-delimiter
      (( finish -= 2 ))
    fi
    _zsh_highlight_arithmetic_contents $(( start + 4 )) $finish
  done
}
# Colours the numbers, variables, operators and brackets in $BUFFER[$1,$2]. Anything else (like a $(command) inside) is left as
# the main highlighter coloured it
_zsh_highlight_arithmetic_contents() {
  local -i i=$1 j depth
  while (( i <= $2 )); do
    case $BUFFER[i] in
      ([0-9]) # e.g. 42, 1.5, 0x1f, 16#ff
        j=i; while (( j < $2 )) && [[ $BUFFER[j+1] == [[:alnum:]_.#] ]]; do (( j++ )); done
        _zsh_highlight_add_highlight $(( i - 1 )) $j arithmetic-number
        i=j ;;
      ([[:alpha:]_$])
        if [[ $BUFFER[i] == '$' && ( $BUFFER[i+1] == '{' || $BUFFER[i+1] == '(' && $BUFFER[i+2] != '(' ) ]]; then
          # ${param} or $(command): skip to its end
          for (( j = i + 1, depth = 0; j <= $2; j++ )); do
            [[ $BUFFER[j] == [\({] ]] && (( depth++ ))
            [[ $BUFFER[j] == [\)}] ]] && (( --depth == 0 )) && break
          done
          i=j
        elif [[ $BUFFER[i] == '$' && $BUFFER[i+1] == '(' ]]; then
          : # a nested $(( )): the loop over expansions colours its delimiters, so just move past the $
        else # a variable, with or without a $
          j=i; while (( j < $2 )) && [[ $BUFFER[j+1] == [[:alnum:]_] ]]; do (( j++ )); done
          _zsh_highlight_add_highlight $(( i - 1 )) $j parameter
          i=j
        fi ;;
      ('`') # `command`: skip to its end
        j=i+1; while (( j < $2 )) && [[ $BUFFER[j] != '`' ]]; do (( j++ )); done
        i=j ;;
      ([\(\)]) _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-bracket ;;
      ('!') # the main highlighter colours a ! as a history expansion unless it's followed by one of these
        [[ $BUFFER[i+1] == ['=({'[:blank:]] ]] && _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-operator ;;
      ([-+*/%\<\>=~^\&\|?:,\;]) _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-operator ;;
    esac
    (( i++ ))
  done
}

# Colour $variables in arguments, which zsh-syntax-highlighting leaves the same as the rest of the argument (it only colours
# them inside "..."). Like the highlighters above, this relies on the main highlighter's cache: it looks in the entries for
# plain arguments, skipping any part that has its own entry (a quoted string, a $(command), etc), as those are coloured already.
# A $variable used as a command isn't affected, as the main highlighter colours it as whatever command it runs
_zsh_highlight_highlighter_parameter_predicate() { _zsh_highlight_highlighter_main_predicate }
_zsh_highlight_highlighter_parameter_paint() {
  emulate -L zsh
  local entry inner
  local -a fields inner_fields
  local -A covered # the positions in the argument that have their own entry
  local -i i j depth
  for entry in $_zsh_highlight__highlighter_main_cache; do # entries are "start end style ..."
    fields=(${(s: :)entry})
    [[ ${fields[3]%,} == $ZSH_HIGHLIGHT_STYLES[default] ]] || continue
    covered=()
    for inner in $_zsh_highlight__highlighter_main_cache; do
      inner_fields=(${(s: :)inner})
      if (( inner_fields[1] >= fields[1] && inner_fields[2] <= fields[2] )) &&
         [[ ${inner_fields[3]%,} != $ZSH_HIGHLIGHT_STYLES[default] ]]; then
        for (( i = inner_fields[1] + 1; i <= inner_fields[2]; i++ )); do covered[$i]=1; done
      fi
    done
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do
      [[ $BUFFER[i] == '$' ]] && (( ! $+covered[$i] )) || continue
      # Skip an escaped \$ (one after an odd number of \s)
      j=i-1; while (( j > fields[1] )) && [[ $BUFFER[j] == '\' ]]; do (( j-- )); done
      (( (i - 1 - j) % 2 )) && continue
      j=i+1
      case $BUFFER[j] in
        ('{') # ${...}: up to the matching }
          depth=0
          while (( j < fields[2] )); do
            [[ $BUFFER[j] == '{' ]] && (( depth++ ))
            [[ $BUFFER[j] == '}' ]] && (( --depth == 0 )) && break
            (( j++ ))
          done ;;
        ([[:alpha:]_]) while (( j < fields[2] )) && [[ $BUFFER[j+1] == [[:alnum:]_] ]]; do (( j++ )); done ;;
        ([0-9]) while (( j < fields[2] )) && [[ $BUFFER[j+1] == [0-9] ]]; do (( j++ )); done ;;
        ([*@#?\$!-]) ;; # special parameters like $? and $#
        (*) continue ;; # not a variable, e.g. a $ on its own
      esac
      _zsh_highlight_add_highlight $(( i - 1 )) $j parameter
      i=j
    done
  done
}

# after main, so they can override main's colours
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main pathunderline arithmetic parameter)
