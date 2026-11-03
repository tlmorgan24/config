# Record every command (and its output) with my cmdlog program (source in the cmdlog/ folder of my config repo). It has
# to sit between the terminal and zsh, so this shell replaces itself with `cmdlog record`, which starts a new zsh (that
# re-reads this file, with CMDLOG_SESSION set so it doesn't do this again). Done first, so nothing below runs twice. If
# cmdlog can't record, it starts the shell anyway (unrecorded). To stop recording, delete ~/.local/bin/cmdlog.

# CMDLOG_SESSION is passed on to every program run from a recorded shell, including ones that open new terminals (e.g. a
# VS Code window opened with `code .`), whose terminals would then skip recording. So only trust it on the terminal it
# was set for, while the shell that set it is still running (so it's not fooled by a closed terminal's reused number).
if [[ -n "$CMDLOG_TTY" ]] && ! { [[ "$CMDLOG_TTY" == "$TTY" ]] && kill -0 "$CMDLOG_PID" 2>/dev/null }; then
  unset CMDLOG_SESSION CMDLOG_TTY CMDLOG_PID
fi
if [[ -o interactive && -t 0 && -t 1 && "$TERM" != dumb && -z "$CMDLOG_SESSION" ]] && (( $+commands[cmdlog] )); then
  # VS Code's shell integration script is in a temporary folder only known to this shell, so pass its location on (see
  # cmdlog section below).
  [[ -n "$VSCODE_ZDOTDIR" ]] && export CMDLOG_VSCODE_RC="$VSCODE_ZDOTDIR/.zshrc"
  exec cmdlog record "${commands[zsh]:-/bin/zsh}"
fi
# Note which terminal CMDLOG_SESSION belongs to, and this shell's process, for the check above in shells started later.
[[ -n "$CMDLOG_SESSION" && -z "$CMDLOG_TTY" ]] && export CMDLOG_TTY=$TTY CMDLOG_PID=$$

# Stop here for Claude Code's shell (i.e., the shell it uses to run its own commands), as otherwise my options/aliases 
# below depart from its expected command behaviour and cause things to break.
[[ -n "$CLAUDECODE" ]] && return

setopt interactive_comments  # Interpret '#' as comment, even interactively (i.e. outside scripts).

# Use zsh's completion system, which completes each command's subcommands, flags and arguments (e.g. git branches),
# rather than just file and command names. Includes the completions Homebrew installs in its site-functions folder.
# zsh/complist, loaded first, provides the menu and colours below.
zmodload zsh/complist
autoload -Uz compinit
compinit
# Show matches as a menu, moved through with the arrow keys or Tab and Shift+Tab, with the current match highlighted and
# inserted.
zstyle ':completion:*' menu select
bindkey -M menuselect $'\e[Z' reverse-menu-complete  # Shift+Tab
# Let lowercase letters also match uppercase ones, so `re<tab>` completes README.md, while uppercase letters still only
# match uppercase.
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'
# Colour matches by file type, as eza (i.e. ls) does rather than zsh's default (e.g. red directories), and list them in
# groups under headings (e.g. aliases, functions and external commands).
zstyle ':completion:*' list-colors 'di=1;34' 'ln=36' 'ex=1;32'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*' use-cache on  # Cache the results of slow completions (e.g. brew's package names).

# Completion puts a space after the completed word, which zsh removes again if the next character typed is ;, & or |
# (e.g. `git add README.md;`). Keep the space for & and |, so `git add RE<tab>&&` gives `git add README.md &&` rather
# than `git add README.md&&`.
ZLE_SPACE_SUFFIX_CHARS=$'&|'

# Freeze terminal modes, so zsh puts them back after every command instead of keeping whatever a command left behind.
# E.g. in `head -n 10 $(fzf) | bat`, fzf and less run at the same time: less saves fzf's raw mode as the mode to
# restore, so after it exits every later command's output stair-steps (no carriage return after newlines) and ctrl+c
# stops working. To change modes on purpose: `ttyctl -u; stty ...; ttyctl -f`.
ttyctl -f

# Configure command history.
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
# Write to history file on each command, instead of batching commands to write when shell is closed.
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS  # Discard older duplicate commands in in-memory history.
setopt HIST_SAVE_NO_DUPS  # Discard older duplicate commands when saving to history file.
# If, despite the above, there are still duplicates, do not show them in history search (otherwise pain to scroll back
# to find the command you want).
setopt HIST_FIND_NO_DUPS

# Set the editor.
export EDITOR=vim
export VISUAL=vim

# Use emacs-style line editing (e.g. ctrl+_ to undo, sent by cmd+z). Zsh picks vi mode instead if $EDITOR or $VISUAL
# contains "vi" when it starts, which happens in shells started by programs that inherited them from this file (e.g.
# VS Code opened with `code .`).
bindkey -e

eval "$(starship init zsh)"  # After `brew install starship`

# Succeed if exit status $1 means the command was suspended (e.g. with ctrl+z) rather than finished. Such a status is
# 128 + the number of the signal that stopped it (e.g. 146 for SIGTSTP, number 18 on macOS).
_is_suspended_status() {
  (( $1 > 128 )) && [[ ${signals[$1 - 127]} == (TSTP|TTIN|TTOU|STOP) ]]
}

# After a command is suspended, show starship's "suspended" profile (see starship.toml) instead of the usual prompt,
# which would show the status like a failure. Starship's prompt command gets `$_starship_profile`, empty unless
# suspended.
PROMPT=${PROMPT/" prompt --terminal-width"/" prompt \$_starship_profile --terminal-width"}
_starship_suspended_precmd() {
  local cmd_status=$?
  _starship_profile=
  _is_suspended_status $cmd_status && _starship_profile=--profile=suspended
  return $cmd_status  # Leave $? as it was for any later precmd hooks.
}

precmd_functions+=(_starship_suspended_precmd)

# Keep starship from mangling prompts when the window is resized. 
# 
# zsh can't redraw old prompts, so when the window shrinks, the right prompt on each wraps onto a new line. 
# TRANSIENT_RPROMPT removes it from each prompt once its command runs, so only the current prompt has one.
#
# zsh redraws the current prompt on each resize, but while dragging the window narrower, a redraw can arrive laid out
# for a wider window than it is by then. The right prompt then runs past the edge and wraps, leaving the cursor a row
# lower than zsh thinks, so every later redraw starts a row lower, leaving a blank row above the prompt each time.
# Turning off autowrap (`\e[?7l`) while it's drawn clips it at the edge instead, until the redraw after the last resize
# puts it right. This is safe, as zsh only draws the right prompt when it fits. The left prompt and the command line
# still wrap, as zsh relies on that, so this only helps while the window stays wider than them.
setopt TRANSIENT_RPROMPT
RPROMPT=$'%{\e[?7l%}'$RPROMPT$'%{\e[?7h%}'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='pbcopy'
alias v='pbpaste'
# zcalc is a REPL calculator which removes the need for `echo $((...))`, whilst still being able to work with the
# shell's variables, command substitution etc.
autoload -U zcalc
# So, simply execute `calc` to enter the zcalc REPL calculator (Ctrl-D to exit). Use -f to make everything a float
# (prevent 3/4 = 0 etc).
alias calc='zcalc -f'

# cd with automatic mkdir
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Print the directory that mkcp/mkmv must create, given the command (cp or mv) and its args, using the same rule as
# cp/mv themselves: with GNU's -t DIR it's DIR, otherwise the destination (last operand) is a directory if it ends in /
# or there are multiple sources, else it's a file path, so take its parent. Flags are passed through to cp/mv, so aren't
# counted as operands, and nor are flag values. GNU's -t/--target-directory and -S/--suffix take a value, but no BSD
# flag does (BSD cp has an unrelated -S that takes none), hence checking which we have.
_mkdestdir() {
  local cmd=$1; shift
  local gnu=0
  command $cmd --version &>/dev/null && gnu=1  # BSD rejects --version.
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
      # GNU accepts any unambiguous prefix of a long option, e.g. --target for --target-directory.
      name="${arg%%=*}"
      if (( ${#name} >= 3 )) && [[ --target-directory == "$name"* ]]; then
        if [[ "$arg" == *=* ]]; then target="${arg#*=}"; else target="${@[++i]}"; fi
      elif (( ${#name} >= 4 )) && [[ --suffix == "$name"* && "$arg" != *=* ]]; then
        (( i++ ))
      fi
    elif [[ "$arg" =~ '^-[^tS]*([tS])(.*)$' ]]; then
      # Short flags can be bundled, and the value attached, e.g. -vt DIR or -vtDIR.
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

# Run cp or mv ($1) on the remaining args, first creating the directory they need. If the command fails, the directories
# this created are removed again, but only while empty (rmdir), so anything it did manage to copy/move stays.
_mkrun() {
  local cmd=$1; shift
  local dir="$(_mkdestdir $cmd "$@")"
  local -a created  # Deepest first, so rmdir empties each one's parent before reaching it.
  local d="$dir"
  while [[ ! -e "$d" ]]; do
    created+=("$d")
    d="${d:h}"
  done
  mkdir -p -- "$dir" || return
  _ask_run $cmd "$@" && return
  local ret=$?
  (( ${#created} )) && rmdir -- "${created[@]}" 2>/dev/null
  return $ret
}

# cp with automatic mkdir
mkcp() {
  (( $# >= 2 )) || { echo 'usage: mkcp [flags] source... destination' >&2; return 1 }
  _mkrun cp "$@"
}

# mv with automatic mkdir
mkmv() {
  (( $# >= 2 )) || { echo 'usage: mkmv [flags] source... destination' >&2; return 1 }
  _mkrun mv "$@"
}

# Create the parent directory of file path $1, then print the path. Useful for redirecting to with automatic mkdir, e.g.
# `cmd > "$(mkp out/sub/file)"`.
mkp() {
  (( $# == 1 )) || { echo 'usage: mkp path' >&2; return 1 }
  mkdir -p -- "${1:h}" && print -r -- "$1"
}

# Run cp or mv ($1) with -i on the remaining args, so it asks before overwriting an existing file (declining is the
# default). Read the answer from the terminal rather than stdin, so a prompt in e.g.
# `fd | while read f; do cp $f dest/; done` doesn't use up the list being read, but keep stdin if there's no terminal
# or a source is /dev/stdin (e.g. `pbpaste | cp /dev/stdin file`).
_ask_run() {
  local cmd=$1; shift
  if (( ${@[(Ie)/dev/stdin]} || ${@[(Ie)/dev/fd/0]} )) || ! { : </dev/tty } 2>/dev/null; then
    command $cmd -i "$@"
  else
    command $cmd -i "$@" </dev/tty
  fi
}

# Make cp and mv ask before overwriting (as do mkcp and mkmv). Aliases to functions rather than functions named cp and
# mv, so `\cp`/`\mv` (or `command cp`/`command mv`) still give the real commands, to overwrite without asking. On macOS,
# mv -f also skips the prompt but cp -f doesn't. Declined cp returns 1, but declined mv returns 0. Scripts don't use
# these aliases.
_cp_ask() { _ask_run cp "$@"; }
_mv_ask() { _ask_run mv "$@"; }
compdef _cp _cp_ask  # zsh completes an alias as the command it expands to.
compdef _mv _mv_ask
alias cp=_cp_ask
alias mv=_mv_ask

# Usage: `rm [-dfrRv] <file>...`
#
# Like rm, but move things to the Bin rather than deleting them, so they can be restored with Finder's Put Back (the Bin
# deletes items after 30 days, see copy.sh). Also ask for confirmation before removing my home directory, a directory
# directly in it (e.g. ~/Downloads) or a directory above it, cancelling the whole rm if declined. Otherwise, behave like
# rm: a directory needs -r (or -d if empty), -f ignores missing files, and a problem with one file doesn't stop the
# others. Use `\rm` or `command rm` to delete permanently (e.g. to free up space straight away, or for secrets), or for
# other flags. An alias to a function, like cp and mv, so `\rm` still gives the real rm. Only defined where macOS has
# /usr/bin/trash (macOS 15 onwards). My functions use `command rm` for their own temporary files.
if [[ -x /usr/bin/trash ]]; then
  _rm_bin() {
    setopt local_options extended_glob  # For /## (one or more slashes) below
    local recursive=0 force=0 dirs=0 verbose=0 ret=0 arg name real c
    while [[ "$1" == -?* ]]; do
      [[ "$1" == -- ]] && { shift; break }
      for c in ${(s::)1#-}; do
        case $c in
          r|R) recursive=1 ;;
          f) force=1 ;;
          d) dirs=1 ;;
          v) verbose=1 ;;
          *) echo "rm: -$c isn't supported (as rm moves to the Bin), so use \`command rm\` instead" >&2; return 1 ;;
        esac
      done
      shift
    done
    if (( ! $# )); then
      (( force )) && return 0
      echo 'usage: rm [-dfrRv] file ...' >&2
      return 64  # Same as rm
    fi

    local home="${HOME:A}"
    local -a targets protected contents
    for arg in "$@"; do
      name="${arg%%/##}"  # trash ignores trailing slashes, so removes a symlink itself rather than its target.
      [[ -z "$name" ]] && name=/
      if [[ "${name:t}" == (.|..) ]]; then
        echo 'rm: "." and ".." may not be removed' >&2
        ret=1
        continue
      elif [[ ! -e "$name" && ! -L "$name" ]]; then
        (( force )) || { echo "rm: $arg: No such file or directory" >&2; ret=1 }
        continue
      elif [[ -d "$name" && ! -L "$name" ]]; then
        if (( ! recursive )); then
          contents=("$name"/*(DN[1]))
          if (( ! dirs )); then
            echo "rm: $arg: is a directory" >&2
            ret=1
            continue
          elif (( ${#contents} )); then
            echo "rm: $arg: Directory not empty" >&2
            ret=1
            continue
          fi
        fi
        real="${name:A}"
        if [[ "$real" == "$home" || "${real:h}" == "$home" || "$home" == "$real"/* || "$real" == / ]]; then
          protected+=("$real")
        fi
      fi
      [[ "$name" == -* ]] && name="./$name"  # Otherwise trash takes it as an option.
      targets+=("$name")
    done

    if (( ${#protected} )); then
      echo 'rm: these are your home directory, a directory directly in it, or a directory above it:' >&2
      print -rl -- "  "${^protected} >&2
      read -q "?Move them to the Bin anyway? [y/N] "
      local answer=$?
      echo
      (( answer == 0 )) || return 1
    fi

    (( ${#targets} )) || return $ret
    if ! /usr/bin/trash ${${verbose:#0}:+-v} "${targets[@]}"; then
      echo 'rm: not everything could be moved to the Bin (see above), so use `command rm` to delete permanently' >&2
      return 1
    fi
    return $ret
  }
  compdef _rm _rm_bin
  alias rm=_rm_bin
fi

# Replace BSD with GNU, where I prefer the GNU features (must have done `brew install coreutils` first).
alias sed='gsed -E'  # -E to always use extended regex, gsed to allow e.g. -i without providing a backup file
alias head='ghead'  # For e.g. head -n -N file to get all except the last N lines
# -P to always use PCRE (maximal regex features), ggrep to allow GNU-specific features (but still prefer rg most of the time).
alias grep='ggrep -P'
alias find='gfind'  # But still prefer fd most of the time.
alias tac='gtac'

alias ls='eza -1 --icons=auto'
alias lst='eza -1 --tree --icons=auto'

# -P to always use PCRE (maximal regex features). Note fd does not support this, but still has most features except
# backreferences & lookarounds.
alias rg='rg -P'

# Alias for perl -ane, while still allowing extra flags to be passed without -e swallowing them. Note, can still provide
# -p as a flag (effectively overwrites -n).
#
# Also accept `-R<sep>` for a custom record separator, acting as the record counterpart of -F: <sep> is always a perl
# regex, optionally written `/like this/`, so e.g. a literal | is `-R'\|'`. It must not be able to match the empty
# string, and can't be combined with -0 (or used by pp).
#
# A separator with no regex metacharacters just uses perl's own $/; anything else is extra custom work, as not supported
# by Perl. Neither loads whole files into memory. Both end up with $., eof, -p, etc working as expected.
#
# With -R, $_ keeps its separator unless -l is given. With -l, the separator is stripped from $_ and put back by every
# print (including -p's). This is the exact matched separator the record had, or nothing for a final unterminated
# record. In END blocks, -l prints end in "\n" instead.
#
# My regex highlighter (in syntax-highlighting.zsh) parses these options too, to colour the regexes in them and the
# code, so update it to match if they change.
p() {
  local -a args=() flags=()
  local rs= has_rs=0 has_0=0 regex=0 fs= nl=0 inplace= ip=0 b plain c
  while [[ $1 == -* ]]; do
    [[ $1 == -- ]] && { shift; break; }
    args+=("$1")
    # Split a switch bundle the way perl does: argless switches combine, and a switch that takes a value (-i, -F, -e,
    # -M, ...) uses up the rest of the bundle.
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
  if (( !has_rs )); then
    perl -an "${args[@]}" -e "$1" "${@:2}"
    return
  fi

  (( has_0 )) && { echo "p: -R can't be combined with -0" >&2; return 2; }
  [[ $rs == /*/ && ${#rs} -ge 2 ]] && rs=${rs:1:${#rs}-2}
  [[ -z $rs ]] && { echo "p: -R separator can't be empty" >&2; return 2; }
  [[ $rs =~ '[][\\^$.|?*+(){}]' ]] && regex=1
  (( ip && !regex )) && flags+=("-i$inplace")  # Perl's own -i works with its own $/.
  local split='our @F = length $PRS::FS ? split(/$PRS::FS/) : split(" ");'
  local endfix=';END { $\ = "\n" if $ENV{PRS_L}; select STDOUT }'  # Runs before user END blocks.

  if (( !regex )); then
    PRS_RS=$rs PRS_FS=$fs PRS_L=$nl perl -n "${flags[@]}" -e '
BEGIN { $/ = $ENV{PRS_RS}; ($PRS::FS = $ENV{PRS_FS}) =~ s{^/(.*)/$}{$1}s }
if ($ENV{PRS_L}) { my $o = $_; chomp; $\ = substr $o, length }  # Put back exactly what chomp removed.
'"$split" -e "$1" -e "$endfix" "${@:2}"
    return
  fi

  PRS_RS=$rs PRS_FS=$fs PRS_L=$nl PRS_IP=$ip PRS_BAK=$inplace \
  perl -n -Mopen=IN,':via(PRS)' "${flags[@]}" -e '
BEGIN {
  package PRS;
  our $S = "\x{1E}PRS\x{1E}";  # Sentinel that becomes $/
  our $RS = qr/$ENV{PRS_RS}/;
  if ("" =~ $RS) { warn "p: separator /$ENV{PRS_RS}/ can match the empty string\n"; exit 2 }
  ($PRS::FS = $ENV{PRS_FS}) =~ s{^/(.*)/$}{$1}s;
  # A flush (which perl does to every handle before system, fork, etc) drops whatever is left of the result of the last
  # FILL, so FILL hands out one record at a time and nothing is left over.
  sub PUSHED { bless ["", []], shift }  # [unscanned input, marked records waiting to be handed out]
  sub FILL {  # Mark separators and hold back incomplete tail.
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
        last if !$at_eof && $+[0] >= length $$buf;  # Match might extend further.
        last if !length $sep;  # Ignore empty matches.
        push @$q, $rec . $sep . "\0" . length($sep) . $S;
        $keep = $+[0];
      }
      substr($$buf, 0, $keep) = "";
      if ($at_eof && length $$buf) { push @$q, $$buf; $$buf = "" }
      return undef if $at_eof && !@$q;
    }
  }
  # stdin must be opened by name so the layer applies.
  @ARGV = ("-") unless @ARGV;
  our %name;
  for (@ARGV) { if ($_ eq "-") { $_ = "/dev/stdin"; $name{$_} = "-" } }
  # Emulate -i the way perl does: write each file to a new temporary file beside it, which replaces the file (renamed to
  # the backup first, if an extension was given) once the next file starts or the code ends. If the code dies, the file
  # it was on is left untouched.
  use Fcntl ();
  our ($tmp, $orig);
  sub commit {  # Return false, with a warning, if the file could not be replaced.
    return 1 unless defined $tmp;
    my $t = $tmp; undef $tmp;
    my $ok = close(OUT) && (!length $ENV{PRS_BAK} || rename $orig, $orig . $ENV{PRS_BAK}) && rename $t, $orig;
    unless ($ok) { warn "p: cannot replace $orig: $!\n"; unlink $t }
    return $ok;
  }
  END { if ($? == 0) { commit() or $? = 2 } elsif (defined $tmp) { close OUT; unlink $tmp } }
  our $cur = "";
  $/ = $S;
}
if ($ARGV ne $PRS::cur) {
  $PRS::cur = $ARGV = $PRS::name{$ARGV} // $ARGV;
  if ($ENV{PRS_IP} && $ARGV ne "-") {
    PRS::commit() or exit 2;
    my $t = "$ARGV.prs$$";
    sysopen PRS::OUT, $t, Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL() or die "p: cannot create $t: $!\n";
    ($PRS::orig, $PRS::tmp) = ($ARGV, $t);  # Only once created, so the END block never removes an existing file.
    chmod((stat $ARGV)[2] & 07777, $t);
    select PRS::OUT;
  }
}
if (s/\0(\d+)\Q$PRS::S\E\z//) { $\ = substr($_, -$1, $1, "") if $ENV{PRS_L} }
elsif ($ENV{PRS_L}) { $\ = "" }  # Final record had no separator, so nothing to put back.
'"$split" -e "$1" -e "$endfix" "${@:2}"
}

# Like p, but slurp the whole input as one record (-0777).
pp() { p -0777 "$@"; }

# Usage: `ff [fd args] <code>`
#
# ff stands for "For each File" or "For each output of Fd".
#
# Like fd -x, but run arbitrary shell code for each file found, with the path in $f. The code comes last, everything
# before it goes to fd. Single-quote the code so it's treated as one argument and so the shell does not expand $f before
# it reaches the function. $f needs no double quotes, as it stays one word even if the path contains spaces. E.g.
# `ff -e md 'echo $f; head -1 $f'`. Run in the current shell (aliases, functions and variables all work), reading fd's
# output from fd 3 so commands in the code that read stdin don't swallow the file list. My syntax highlighting (in
# syntax-highlighting.zsh) colours the code as shell code, and the fd pattern among the fd args as a regex, so update it
# to match if the arguments change.
ff() {
  local _ff_cmd=${@[-1]} f  # The name is prefixed so the code can't change it by accident.
  while IFS= read -r -d '' f <&3; do eval "$_ff_cmd"; done 3< <(fd -0 "${@[1,-2]}")
}

# Usage: `bf [fd args] <code>`
#
# bf stands for "Batch Files" or "Batch output of Fd".
#
# Like fd -X, but the batch counterpart of ff: run arbitrary shell code once, with every path fd finds in the array $f,
# so e.g. `wc -l $f` passes them all to one wc. The same code works in ff, but runs once per file there. Same arguments,
# quoting rules and current-shell behaviour as ff, and $f needs no double quotes either, as each path stays one word.
# Don't run the code if fd finds nothing. Unlike fd -X, don't split a long list across several runs, so an external
# command given a huge list can fail with "argument list too long" (functions and builtins have no limit). My syntax
# highlighting (in syntax-highlighting.zsh) colours the code as shell code, and the fd pattern among the fd args as a
# regex, so update it to match if the arguments change.
bf() {
  local _bf_cmd=${@[-1]} _bf_out  # The names are prefixed so the code can't change them by accident.
  local -a f
  _bf_out=$(fd -0 "${@[1,-2]}") || return
  f=(${(0)_bf_out})
  (( $#f )) || return 0
  eval "$_bf_cmd"
}

# Usage: `_record_code_stdin [files]`
#
# Succeed if fr, fl, br or bl would read their records from stdin (no files given, or one is -), putting in REPLY what
# their code reads as its stdin instead: the terminal, or /dev/null if there isn't one, as with xargs -o. The code can't
# share stdin with the records, as in fr and fl it would race p for them (losing some), and in br and bl they've all
# been read by the time it runs.
_record_code_stdin() {
  (( ! $# || ${@[(Ie)-]} )) || return
  REPLY=/dev/null
  { : </dev/tty } 2>/dev/null && REPLY=/dev/tty
  return 0
}

# Usage: `_for_each_record <name> <sep> <code> [files]`
#
# Run the code for each record, as fr does, but with the record in the variable named, for fr and fl. The code reads its
# stdin from fd 4 if _record_code_stdin says to, else from the function's own.
_for_each_record() {
  local _fr_name=$1 _fr_sep=$2 _fr_cmd=$3 _fr_tty=/dev/null s REPLY
  local -i _fr_in=0  # The fd the code reads its stdin from
  local $_fr_name
  shift 3
  _record_code_stdin "$@" && _fr_in=4 _fr_tty=$REPLY
  while IFS= read -r -d '' $_fr_name <&3 && IFS= read -r -d '' s <&3; do eval "$_fr_cmd" <&$_fr_in; done \
    3< <(p -l -R"$_fr_sep" 'printf "%s\0%s\0", $_, $\' "$@") 4<$_fr_tty
}

# Usage: `_batch_records <name> <sep> <code> [files]`
#
# Run the code once, as br does, but with every record in the array named, for br and bl. The code reads its stdin from
# fd 4 if _record_code_stdin says to, else from the function's own.
_batch_records() {
  local _br_name=$1 _br_cmd=$3 _br_out _br_tty=/dev/null REPLY
  local -i _br_in=0  # The fd the code reads its stdin from
  local -a $_br_name
  _br_out=$(p -l -R"$2" 'printf "%s\0", $_' "${@:4}") || return
  set -A $_br_name "${(@0)_br_out}"
  shift -p $_br_name  # Drop the empty string after the last record's NUL.
  (( ${(P)#_br_name} )) || return 0
  _record_code_stdin "${@:4}" && _br_in=4 _br_tty=$REPLY
  { eval "$_br_cmd" <&$_br_in } 4<$_br_tty
}

# Usage: `fr <sep> <code> [files]`
#
# fr stands for "For each Record".
#
# Like ff, but for records split on a regex (via p -R), with the record in $r and the exact separator that ended it in
# $s (empty for a final unterminated record). <sep> is anything p -R takes, e.g. `'\n\n+'` or `/,\s*/`. Read stdin if no
# files are given (or one is -), and then connect the code's stdin to the keyboard instead (or to empty input if there's
# no terminal, e.g. under cron), so commands in the code can't steal records from it. It's still only the default source
# of stdin, so a pipe or redirect in the code takes priority. Records containing NUL bytes get split there. My syntax 
# highlighting (in syntax-highlighting.zsh) colours <sep> as a regex and <code> as shell code, so update it to match if 
# the arguments change.
fr() { _for_each_record r "$@"; }

# Usage: `fl <code> [files]`
#
# fl stands for "For each Line".
#
# fr with a newline separator, but with the line in $l ($s is a newline, or empty for an unterminated last line). E.g.
# `fl 'mkdir $l' names.txt`. A literal newline (rather than '\n') lets p use perl's own $/, skipping the slower regex
# splitting. My syntax highlighting (in syntax-highlighting.zsh) colours <code> as shell code, so update it to match if
# the arguments change.
fl() { _for_each_record l $'\n' "$@"; }

# Usage: `br <sep> <code> [files]`
#
# br stands for "Batch Records".
#
# The batch counterpart of fr: run the code once, with every record in the array $r (and no $s), so e.g. `cmd $r` passes
# them all to one cmd. E.g. `printf 'a,b,c' | br , 'echo $#r items: $r'`. Same arguments, quoting rules, current-shell
# behaviour and stdin handling as fr, and like bf, don't run the code if there are no records, and don't split a long
# list across several runs. Keep empty records in $r, which an unquoted $r drops (as with any array) but `"$r[@]"`
# keeps. My syntax highlighting (in syntax-highlighting.zsh) colours <sep> as a regex and <code> as shell code, so
# update it to match if the arguments change.
br() { _batch_records r "$@"; }

# Usage: `bl <code> [files]`
#
# bl stands for "Batch Lines".
#
# br with a newline separator, but with the lines in $l. E.g. `bl 'mkdir $l' names.txt` makes every directory with one
# mkdir. As with fl, a literal newline lets p skip the slower regex splitting. My syntax highlighting (in
# syntax-highlighting.zsh) colours <code> as shell code, so update it to match if the arguments change.
bl() { _batch_records l $'\n' "$@"; }

# Like echo, but arguments end up joined without a space separating them. E.g. `concat hello world` gives `helloworld`,
# whereas `echo hello world` gives `hello world`.
concat() {
  printf '%s' "$@"
}

alias python='python3'

# Usage: `govi [directory [module name]]`
#
# Quickly run a draft Go program: mkcd into the directory, init a module there, create boilerplate main.go to edit in
# vim, then automatically format, tidy modules and run. The directory defaults to CWD (pass "" to give a module name
# without changing directory) and the module name defaults to draft. Refuse to run if main.go already exists in the
# directory, so an existing program isn't overwritten. Vim opens on the Println line. Quit with :cq to skip formatting
# and running (loses unsaved changes).
govi() {
  _goinit govi "$@" && vim +6 main.go && go fmt && go mod tidy && go run .
}

# Like govi, but open the directory in VS Code for more in-depth work, and don't run anything.
goco() {
  _goinit goco "$@" && code . -g main.go:6
}

# Shared setup for govi and goco: mkcd, init the module and create main.go. First argument is the caller's name, for
# errors.
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

# Convenient git shortcuts
alias ga='git add'
alias gaa='ga -u'  # Add tracked files (like the -a in `git commit -a`).
alias gad='ga .'  # 'd' stands for 'dot' or 'directory', as stages entire current directory (except .gitignored)
alias gap='ga -p .'  # Stage changes interactively, patch by patch (instead of entire files).
# gaar and gadr are functions rather than aliases, because zsh expands an alias before completing it, so it would
# complete the paths as `git restore --staged` does, offering only files already staged. Complete them instead as the
# commands that offer the files the first step will stage: `git restore` for gaar (tracked files with unstaged changes,
# as `git add -u` stages) and `git add` for gadr (modified and untracked files, as `git add .` stages).
compdef _git gaar=git-restore
gaar() { gaa && git restore --staged "$@"; }

compdef _git gadr=git-add
gadr() { gad && git restore --staged "$@"; }

alias gc='git commit -m'
alias gca='gaa && gc'
alias gcd='gad && gc'
alias gcp='gap && gc'
# gcf stands for 'git commit fixup', because its effect is equivalent to fixing up the previous commit.
alias gcf='git commit --amend --no-edit'
# So you can locally change the .gitignore to ignore personal files without worrying about committing the gitignore
# itself.
alias gci='gadr .gitignore && gc'
alias gcaf='gcf -a'
alias gcdf='gad && gcf'
alias gcif='gadr .gitignore && gcf'

alias gl='git log --oneline'
alias glt='gl --graph --all'  # Tree view of all commits
alias gs='git status'

# Usage: `push [<options>]`
#
# Push current branch to its upstream (if one is configured) or the same-name branch on origin (setting this as the
# upstream). Options (e.g. `--tags`) are passed to `git push`, except -f/--force becomes --force-with-lease
# --force-if-includes, so a force push can't overwrite commits on the remote that haven't been integrated locally. Run
# `git push --force` directly to overwrite them anyway.
push() {
  local -a args lease=(--force-with-lease --force-if-includes)
  local arg pre post i
  for (( i = 1; i <= $#; i++ )); do
    arg="${@[i]}"
    if [[ "$arg" == -- ]]; then
      args+=("${@[i,-1]}")
      break
    elif [[ "$arg" == --force ]]; then
      args+=("${lease[@]}")
    elif [[ "$arg" == -[^-]* ]]; then
      # Short flags can be bundled (e.g. -uf), and -o takes the rest of the bundle (or the next argument) as its value.
      pre="${${arg#-}%%o*}"  # Flags before any o
      post="${arg:$(( ${#pre} + 1 ))}"  # o and its value, if present
      if [[ "$pre" == *f* ]]; then
        pre="${pre//f}"
        args+=("${lease[@]}")  # Before the rest of the bundle, which may end in an -o awaiting its value
        [[ -n "$pre$post" ]] && args+=("-$pre$post")
      else
        args+=("$arg")
      fi
      [[ "$post" == o ]] && args+=("${@[++i]}")
    else
      args+=("$arg")
    fi
  done

  if git rev-parse '@{u}' >/dev/null 2>&1; then
    git push "${args[@]}"
  else
    git push -u "${args[@]}" origin HEAD
  fi
}

# Usage: `pull [<options>]`
#
# Merge current branch's remote into local (assuming remote source is called "origin"). Options (e.g. `--rebase`) are
# passed to `git pull`.
pull() {
  local branch="$(git branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "pull: must be on a branch" >&2
    return 1
  fi

  git pull "$@" origin "$branch"
}

# Usage: `reset-origin <branch>`
#
# Reset chosen local branch to its corresponding remote branch (assumes remote source is called "origin"). The remote
# branch is automatically fetched. If specified branch is current branch, uses `git reset --keep`. If specified branch
# is NOT current branch, uses `git branch -f`. Both ensure uncommitted changes are preserved (but --keep does not
# preserve whether a change is staged vs unstaged; all become unstaged).
#
# Before resetting, ask for confirmation if the local branch has commits that the remote branch doesn't, listing them,
# as the reset drops them (leaving them only in the reflog).
reset-origin() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "reset-origin: must explicitly supply a branch" >&2
    return 1
  fi

  local current_branch="$(git branch --show-current)"  # Empty if not currently on a branch
  if [[ "$target" == HEAD && -n "$current_branch" ]]; then
    # Must use full branch name, not HEAD, as origin/HEAD refers to origin/main, not necessarily the intended branch.
    target="$current_branch"
  elif [[ "$target" == HEAD ]]; then
    echo "reset-origin: supplied HEAD as the branch, but not currently on any branch" >&2
    return 1
  fi

  git fetch origin "$target" || { echo "reset-origin: no remote branch fetched" >&2; return 1; }

  local dropped  # Local commits not on the remote branch (empty if the local branch doesn't exist yet)
  dropped="$(git log --oneline "origin/$target..refs/heads/$target" 2>/dev/null)"
  if [[ -n "$dropped" ]]; then
    echo "reset-origin: $target has commits that origin/$target doesn't, which the reset will drop:" >&2
    echo "$dropped" >&2
    read -q "?Continue? [y/N] "
    local answer=$?
    echo
    [[ $answer -eq 0 ]] || return 1
  fi

  if [[ "$target" == "$current_branch" ]]; then
    git reset --keep "origin/$target"
  else
    git branch -f "$target" "origin/$target"
  fi
}

reset-main() {
  reset-origin main
}

# Usage: `rebase-origin <branch> [<options>]`
#
# Rebase current branch onto chosen remote branch (assumes remote source is called "origin"). The remote branch is
# automatically fetched before the rebase. Options (e.g. `--autostash`) are passed to `git rebase`.
rebase-origin() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "rebase-origin: must explicitly supply a target branch" >&2
    return 1
  fi

  local current_branch="$(git branch --show-current)"  # Empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "rebase-origin: not currently on any branch" >&2
    return 1
  fi

  git fetch origin "$target" || { echo "rebase-origin: no remote branch fetched" >&2; return 1; }
  git rebase "${@:2}" "origin/$target"
}

# Usage: `rebase-main [<options>]`
rebase-main() {
  rebase-origin main "$@"
}

# Usage: `merge-origin <branch> [<options>]`
#
# Merge chosen remote branch into current branch (assumes remote source is called "origin"). The remote branch is
# automatically fetched before the merge. Options (e.g. `--no-ff`) are passed to `git merge`.
merge-origin() {
  local source="$1"
  if [[ -z "$source" ]]; then
    echo "merge-origin: must explicitly supply a source branch" >&2
    return 1
  fi

  local current_branch="$(git branch --show-current)"  # Empty if not currently on a branch
  if [[ -z "$current_branch" ]]; then
    echo "merge-origin: not currently on any branch" >&2
    return 1
  fi

  git fetch origin "$source" || { echo "merge-origin: no remote branch fetched" >&2; return 1; }
  git merge "${@:2}" "origin/$source"
}

# Usage: `merge-main [<options>]`
merge-main() {
  merge-origin main "$@"
}

# Make gh CLI prompt inputs more natural (otherwise, sending escape sequences like alt+backspace causes a crash).
export GH_EXPERIMENTAL_PROMPTER=1

# Usage: `pr [options]`
#
# Push current branch and create PR for it, using the .md file passed with `--md <filepath>` (or `--md=<filepath>`) and
# taking its level-1 header as the PR title. Other options are passed to `gh pr create`.
# If `--base` not specified, the branch to merge into will be the repository's default branch (i.e. main).
#
# Before pushing, refuse if the current branch is the base branch, has no commits that aren't in the base, or already has
# an open PR, and ask for confirmation if the branch already exists on origin (e.g. it's someone else's branch you
# checked out).
pr() {
  local filepath=""
  local base=""  # Branch to merge into
  local -a opts  # Options to pass to `gh pr create`
  local title_body_opt=""  # Title/body option passed, which would conflict with `--md`

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --md)
        if [[ $# -lt 2 ]]; then
          echo "pr: --md requires a filepath" >&2
          return 1
        fi
        filepath="$2"
        shift 2
        ;;
      --md=*)
        filepath="${1#--md=}"
        shift
        ;;
      -B|--base)
        if [[ $# -lt 2 ]]; then
          echo "pr: $1 requires a branch" >&2
          return 1
        fi
        base="$2"
        opts+=("$1" "$2")
        shift 2
        ;;
      -B?*|--base=*)
        base="${1#(-B|--base=)}"
        opts+=("$1")
        shift
        ;;
      -[tbF]*|--title|--title=*|--body|--body=*|--body-file|--body-file=*)
        title_body_opt="${1%%=*}"
        opts+=("$1")
        shift
        ;;
      *)
        opts+=("$1")
        shift
        ;;
    esac
  done

  if [[ -n "$filepath" && ! -f "$filepath" ]]; then
    echo "pr: no such file: $filepath" >&2
    return 1
  fi
  if [[ -n "$filepath" && -n "$title_body_opt" ]]; then
    echo "pr: can't combine $title_body_opt with --md, which already sets the title and body" >&2
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "Not authenticated - follow steps below to log in..."
    if ! gh auth login; then
      echo "pr: failed to authenticate. Either the login failed or you have not installed gh" >&2
      return 1
    fi
  fi

  local branch="$(git branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "pr: must be on a branch" >&2
    return 1
  fi
  if [[ -z "$base" ]]; then
    base="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)" || return 1
  fi
  if [[ "$branch" == "$base" ]]; then
    echo "pr: current branch is the base branch ($base); create a new branch for the PR first" >&2
    return 1
  fi

  # Fetch the base first so commits already merged into it don't look new.
  git fetch -q origin "$base" || return 1
  if [[ -z "$(git rev-list "origin/$base..HEAD")" ]]; then
    echo "pr: $branch has no commits that aren't already in $base" >&2
    return 1
  fi

  local open_prs  # URLs of open PRs from the current branch
  open_prs="$(gh pr list --head "$branch" --state open --json url -q '.[].url')" || return 1
  if [[ -n "$open_prs" ]]; then
    echo "pr: $branch already has an open PR, so not pushing:" >&2
    echo "$open_prs" >&2
    return 1
  fi

  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    read -q "?pr: $branch already exists on origin, so pushing will add to it. Continue? [y/N] "
    local answer=$?
    echo
    [[ $answer -eq 0 ]] || return 1
  fi

  if [[ -z "$filepath" ]]; then
    # Use gh's default prompt to ask for title/body.
    push || return 1
    gh pr create "${opts[@]}"
    return 0
  fi

  local tmp  # Temporary file with title removed, to use as PR body
  tmp=$(mktemp) || return 1
  # Remove tmp afterwards with the `always` construct (`trap 'rm -f "$tmp"' RETURN` isn't valid zsh syntax).
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
    gh pr create -t "$title" -F "$tmp" "${opts[@]}"
  } always {
    command rm -f "$tmp"
  }
}

# Usage: `repo [gh repo create options] <path>`
#
# Create a GitHub repo, set as the origin of the directory specified by `<path>` (and named as the part of the absolute
# path after the final `/`). Private by default: pass --public or --internal to override. Other options are passed to
# `gh repo create`. If the path is an existing directory (e.g. `.`), it's git initialised (if not already), and any
# commits are pushed to the new GitHub repo. If the path doesn't exist, the new GitHub repo is cloned to that location.
# gh doesn't allow --license, --gitignore or --template in the former case. In either case, the CWD becomes the
# directory specified by <path> (i.e., the repo clone). Refuse if the directory already has an origin remote, before
# creating anything.
repo() {
  local dir="$argv[-1]"
  if [[ $# -eq 0 || "$dir" == -* ]]; then
    echo "repo: must supply a path as the last argument" >&2
    return 1
  fi
  local -a opts=("${argv[1,-2][@]}")
  local abs="${dir:a}"
  local name="${abs:t}"

  local visibility=--private
  local opt
  for opt in "${opts[@]}"; do
    if [[ "$opt" == --public || "$opt" == --private || "$opt" == --internal ]]; then
      visibility=""
    fi
  done
  opts=(${visibility:+"$visibility"} "${opts[@]}")

  if ! gh auth status >/dev/null 2>&1; then
    echo "Not authenticated - follow steps below to log in..."
    if ! gh auth login; then
      echo "repo: failed to authenticate. Either the login failed or you have not installed gh" >&2
      return 1
    fi
  fi

  # Check before creating anything, so a GitHub repo isn't created that can't then be set as the origin.
  if [[ -d "$abs" && "$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null)" == "${abs:A}" ]] &&
    git -C "$abs" remote get-url origin >/dev/null 2>&1; then
    echo "repo: $dir already has an origin remote" >&2
    return 1
  fi
  if gh repo view "$name" >/dev/null 2>&1; then
    echo "repo: you already have a GitHub repo named $name" >&2
    return 1
  fi

  if [[ ! -e "$abs" ]]; then
    # gh clones into ./name, so run it from the parent directory.
    mkdir -p "${abs:h}" && (cd "${abs:h}" && gh repo create "$name" --clone "${opts[@]}") && cd "$abs"
  elif [[ -d "$abs" ]]; then
    if [[ "$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null)" != "${abs:A}" ]]; then
      git -C "$abs" init || return 1
    fi
    if git -C "$abs" rev-parse -q --verify HEAD >/dev/null; then
      opts+=(--push)
    fi
    gh repo create "$name" --source="$abs" "${opts[@]}" && cd "$abs"
  else
    echo "repo: $dir exists but isn't a directory" >&2
    return 1
  fi
}

# git clone with automatic cd into cloned repository. Takes the same args as git clone.
clonecd() {
  setopt local_options extended_glob  # For /## (one or more slashes) below.
  local -a valued=(--origin --branch --upload-pack --template --config --depth --shallow-since --shallow-exclude
    --reference --reference-if-able --separate-git-dir --jobs --filter --server-option --bundle-uri --ref-format
    --revision)
  local -a operands
  local arg i bare=0
  for (( i = 1; i <= $#; i++ )); do
    arg="${@[i]}"
    if [[ "$arg" == -- ]]; then
      operands+=("${@[i+1,-1]}")
      break
    elif [[ "$arg" != -?* ]]; then
      operands+=("$arg")
    elif [[ "$arg" == --bare || "$arg" == --mirror ]]; then
      bare=1
    elif (( ${valued[(Ie)$arg]} )); then
      (( i++ ))
    elif [[ "$arg" =~ '^-[^obucj]*[obucj]$' ]]; then
      (( i++ ))  # Short flags can be bundled, e.g. -qb main, and only the last one can take a value.
    fi
  done
  [[ -n "${operands[1]}" ]] || { echo 'usage: clonecd [flags] repository [directory]' >&2; return 1 }
  local dir="${operands[2]}"
  if [[ -z "$dir" ]]; then
    # Name it the way git does, e.g. https://github.com/user/repo.git/ and git@github.com:user/repo.git both give repo
    # (or repo.git if bare).
    dir="${operands[1]%%/##}"
    dir="${${${dir%/.git}%.git}%.bundle}"
    dir="${dir##*[/:]}"
    (( bare )) && dir+=.git
  fi
  git clone "$@" && cd -- "$dir"
}

# Like clonecd, but also open the cloned repository in VS Code.
cloneco() {
  clonecd "$@" && code .
}

# Configure fzf.
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

# Make shortcuts that open fzf use the whole window, rather than the 80% above, by giving `--height=100%` in each one's
# own options (fzf's, set up by `source <(fzf --zsh)` below, and mine). Otherwise, in a short window, fzf scrolls the
# screen to make room for itself below the prompt, pushing the first lines of my 3-line prompt off the top, where zsh
# can't redraw them, so they're left behind each time fzf closes. (Commands typed at the prompt, like `browse` below, are fine
# at 80%, as their prompt doesn't get redrawn.)
export FZF_CTRL_T_OPTS=--height=100%
export FZF_ALT_C_OPTS=--height=100%
export FZF_COMPLETION_OPTS=--height=100%

# Additional fzf configuration for zoxide's `zi` command
#
# zoxide passes entries as `<score> <directory>`. We hide the score from the list, and keep only the directory as the
# searchable/displayed field. The score is still used for zoxide's ranking, which it uses to pass entries to fzf in rank
# order. `--with-nth=2..` hides zoxide's score (the first field). `--bind=start:change-nth(1)` overrides zoxide's
# default fzf config to ensure fzf searches the new 1st field.
#
# --no-sort prevents fzf from reordering the inputs based on fuzzy match score, because zoxide already passes the
# directories in its ranked order, and fzf's fuzzy score reordering would not consider the original ranking. --exact
# prevents fuzzy search, i.e., must be a substring rather than subsequence. This is needed because, with --no-sort, fzf
# will not change the ranking based on search likelihood. E.g. if have folders called "Downloads" and "was", with
# "Downloads" ranking higher, typing "was" (without --exact) would still match "Downloads" (because it still has the
# "was" subsequence), and "Downloads" would still take priority as a match, even though "was" is unlikely to refer to
# "Downloads".
#
# `lsc` is my custom command for displaying the contents of the previewed directory. zoxide normally uses `ls`, but its
# column formatting produces inconsistent spacing. lsc is more compact (hence the 'c'). `{2..}` is fzf syntax for
# passing the second field onward (i.e. pass the directory, not the score, to lsc).
#
# `--height=100%` for the same reason as FZF_CTRL_T_OPTS above, because when zoxide opens fzf from tab completion
# (`z foo<space><tab>`), it redraws the prompt afterwards like a shortcut. `zi` overrides this (see below), as it's
# typed at the prompt so doesn't the whole window.
export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS
--height=100%
--exact
--no-sort
--cycle
--keep-right
--with-nth=2..
--bind='start:change-nth(1),ctrl-z:ignore,btab:up,tab:down'
--preview='lsc "$FZF_PREVIEW_COLUMNS" {2..}'
--preview-window=down,30%,sharp
--exit-0"

# Set options for fzf's own ctrl+R shortcut to fuzzy search through shell history (only used if cmdlog isn't installed,
# as otherwise my cmdlog-history-widget replaces it, see the cmdlog section below). `--height=100%` is explained above
# FZF_CTRL_T_OPTS.
export FZF_CTRL_R_OPTS="\
--height=100%
--with-nth=2..
--layout=default"

export BAT_THEME="Catppuccin Mocha"
eval "$(zoxide init zsh)"  # After `brew install zoxide`

# Keep `zi` at 80% like other commands typed at the prompt (e.g. `browse`), overriding the `--height=100%` in
# _ZO_FZF_OPTS (only needed for zoxide's tab completion). zoxide's own `zi` just calls `__zoxide_zi`, and fzf uses the
# last `--height` it's given.
zi() {
  _ZO_FZF_OPTS="$_ZO_FZF_OPTS --height=80%" __zoxide_zi "$@"
}

# Enable fzf's shortcuts (fzf is still runnable without this), after `brew install fzf` and option configuration.
source <(fzf --zsh)

# Usage: `browse [options] [directory]`
#
# Custom file browser. Output: full path to the chosen file/directory. By default, allow multi-select (select with tab,
# confirm selection with enter, sent as separate lines of stdout). If initial directory not provided, assume current
# working directory. From the initial directory, can interactively browse by pressing left to come out of the directory,
# right to go into the highlighted directory. Press ctrl+f to instead search every file below the directory, and again
# to browse the highlighted entry's directory.
#
# Options:
#   - `--group-directories-first`: self explanatory
#   - `--no-multi`: opt out of multi-select.
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

  local FZF_OPTS=(  # fzf options specific to this browse function, in addition to FZF_DEFAULT_OPTS
    --delimiter=$'\t'  # fzf is provided `full_path<TAB>pretty_path` fields.
    --with-nth=2..  # Only use the pretty path for display/search.
    --accept-nth=1  # Only output the full path.
    --bind="right:transform(browse-in ${BROWSE_OPTS_STR} {1}),left:transform(browse-out ${BROWSE_OPTS_STR} {1})"
    --bind="ctrl-f:transform(browse-search ${BROWSE_OPTS_STR} {1})"
    --preview="display-contents {1}"  # Pass the full path for displaying contents.
    --ansi  # Preserve colours
  )

  if [[ "$multi" == true ]]; then
    FZF_OPTS+=(--multi)
  fi

  provide-contents "${PROVIDE_OPTS[@]}" "$directory" | fzf "${FZF_OPTS[@]}"
}

# Wrap cd so that, if no argument is provided, it uses my custom file browser.
cd() {
  if (( $# == 0 )); then
    builtin cd "$(browse --no-multi --group-directories-first)"
  else
    builtin cd "$@"  # Pass through so special arguments like `-`, `-2` and `-P` still work.
  fi
}

# Ctrl+f: choose file(s) with my file browser, and insert them into the command line at the cursor (like fzf's ctrl+t).
browse-widget() {
  local -x FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --height=100%"  # Use the whole window (see FZF_CTRL_T_OPTS).
  local selected=( ${(f)"$(browse)"} )  # One entry per line (empty if cancelled)
  if (( ${#selected} )); then
    LBUFFER+="${(j: :)${(@q-)selected}} "  # Quote each path only if needed, then join with spaces.
  fi
  zle reset-prompt
}

zle -N browse-widget
bindkey -M emacs '^F' browse-widget
bindkey -M viins '^F' browse-widget
bindkey -M vicmd '^F' browse-widget

# Usage: `switch [<git switch args>]`
#
# Custom git branch switcher that previews the log of each branch. With any arguments, just run `git switch` with them
# instead (like `cd` with `browse`).
switch() {
  if (( $# )); then
    git switch "$@"
    return
  fi

  # Declare separately, as `local` would replace git's exit status with its own (always 0).
  local branches
  branches=$(git branch --sort=-committerdate --format='%(refname:short)')  # Most recent tip first
  if (( $? != 0 )); then
    echo 'switch: git branch failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$branches" ]]; then
    echo "switch: no branches found" >&2
    return 1
  fi

  local FZF_OPTS=(  # fzf options specific to this function, in addition to FZF_DEFAULT_OPTS
    --height=100%  # Take up entire terminal window
    --preview="display-logs {}"  # `{}` injects the branch name currently selected.
    --no-sort  # Keep the most recent first while filtering, rather than ranking by match quality.
    --exact  # Match substrings only, as unsorted subsequence matches are mostly noise (see `zi`).
    # fzf always keeps at least one list row, plus one more for each border line the preview window has, so hide the
    # preview's border and the separator line to leave only the prompt and one list row above the preview. Then colour
    # everything in that row with fzf's background colour (`bg` in FZF_DEFAULT_OPTS), so it looks like a gap.
    --preview-window=down,99%,border-none  # Make preview window take up as much space as possible
    --no-separator
    --color='fg+:#1e1e2e,bg+:#1e1e2e,hl+:#1e1e2e,pointer:#1e1e2e,gutter:#1e1e2e,scrollbar:#1e1e2e'
    --color='preview-scrollbar:#585b70'  # Restore the `border` colour, as setting `scrollbar` also changed this.
  )

  local branch
  branch=$(echo "$branches" | fzf "${FZF_OPTS[@]}") || return  # Don't switch if fzf was cancelled.
  git switch "$branch"
}

# Usage: `checkout [<git checkout args>]`
#
# Custom git checkout that previews the logs of surrounding commits. With any arguments, just run `git checkout` with
# them instead (like `switch`).
checkout() {
  if (( $# )); then
    git checkout "$@"
    return
  fi

  # Use short hashes, to exactly match the git log --oneline used in the preview.
  local commits  # Declared separately, like `branches` in `switch`
  commits=$(git log --all --format='%h')
  if (( $? != 0 )); then
    echo 'checkout: git log failed: perhaps you are not in a git repository' >&2
    return 1
  elif [[ -z "$commits" ]]; then
    echo "checkout: no commits found" >&2
    return 1
  fi

  local FZF_OPTS=(  # fzf options specific to this function, in addition to FZF_DEFAULT_OPTS
    --height=100%  # Take up entire terminal window
    # `{}` injects the commit hash currently selected (can use the same program as for branches!).
    --preview="display-logs {}"
    --no-sort  # Keep the commits in date order while filtering, like the branches in `switch`.
    --exact  # Match substrings only, as subsequence matches of hex hashes are mostly noise.
    --preview-window=down,99%,border-none  # Make preview window take up as much space as possible
    # Leave only the prompt and a row that looks like a gap above the preview (see `switch`).
    --no-separator
    --color='fg+:#1e1e2e,bg+:#1e1e2e,hl+:#1e1e2e,pointer:#1e1e2e,gutter:#1e1e2e,scrollbar:#1e1e2e'
    --color='preview-scrollbar:#585b70'
  )

  local commit
  commit=$(echo "$commits" | fzf "${FZF_OPTS[@]}") || return  # Don't check out if fzf was cancelled.
  git checkout "$commit"
}

# Set up command recording with cmdlog. See the top of this file for how cmdlog gets started. The hooks below print
# invisible "markers" telling cmdlog where each command's output starts and ends. Each marker contains a secret only
# this shell and its cmdlog know, so program output can't fake one. cmdlog removes the markers before passing output on
# to the terminal.

# Keep the secret as an unexported variable, so programs run from this shell never see it.
if [[ -n "$CMDLOG_SECRET" ]]; then
  typeset -g _cmdlog_secret="$CMDLOG_SECRET"
  unset CMDLOG_SECRET
fi

if [[ -n "$_cmdlog_secret" ]]; then
  # Percent-encodes the characters that can't appear inside a marker: ';' separates its fields, BEL ends it, ESC could
  # start another escape sequence, and the terminal would turn a newline into \r\n. Result goes in $REPLY.
  _cmdlog_encode() {
    REPLY=${1//\%/%25}
    REPLY=${REPLY//;/%3B}
    REPLY=${REPLY//$'\a'/%07}
    REPLY=${REPLY//$'\e'/%1B}
    REPLY=${REPLY//$'\n'/%0A}
    REPLY=${REPLY//$'\r'/%0D}
  }

  # Run just before each command, with $1 as the command exactly as typed.
  _cmdlog_preexec() {
    local REPLY dir
    _cmdlog_encode "$PWD"
    dir=$REPLY
    _cmdlog_encode "$1"
    print -rn -- $'\e]7777;'"$_cmdlog_secret;start;$dir;$REPLY"$'\a'
    _cmdlog_running=1
  }

  # Run just before each prompt, so $? is still the exit status of the command that just finished. Also run before the
  # first prompt, and after pressing enter on an empty line, when no command ran.
  _cmdlog_precmd() {
    local cmd_status=$?
    if (( _cmdlog_running )); then
      print -rn -- $'\e]7777;'"$_cmdlog_secret;end;$cmd_status"$'\a'
      _cmdlog_running=0
    fi
    return $cmd_status  # Leave $? as it was for the other precmd hooks (e.g. starship's, which shows the status).
  }

  # Put these hooks first, so the output cmdlog captures doesn't include what other hooks print.
  preexec_functions=(_cmdlog_preexec ${preexec_functions:#_cmdlog_preexec})
  precmd_functions=(_cmdlog_precmd ${precmd_functions:#_cmdlog_precmd})
fi

# Save the context ~/.zsh/highlight-commands.zsh needs to colour commands as they're coloured on the command line (for
# my ctrl+r and cmd+e) to a new temp file, and put its path in $REPLY. This is the shell's aliases, function names and
# options, as they decide how commands are coloured (e.g. without an alias, it's an unknown command, so red). Functions
# starting with _ are left out, as they're mostly completions. The caller deletes the file.
_save_highlight_context() {
  REPLY=$(mktemp) || return
  {
    alias -L
    local f
    # Not the ones named like completion functions (`_*`), bar those that aliases run (e.g. rm's _rm_bin).
    for f in ${(u)${(k)functions:#_*}} ${(u)${(M)${(v)aliases%% *}:#_*}}; do
      (( $+functions[$f] )) && print -r -- "functions[${(q)f}]=:"
    done
    print -r -- "typeset -A zsyh_user_options=(${(@qkv)options})"
    # Which of grep, sed etc are GNU's, as found so far, so it needn't check again
    print -r -- "_zsh_highlight_regex_gnu=(${(@qkv)_zsh_highlight_regex_gnu})"
  } > $REPLY
}

# Ctrl+r: search the recorded history (replacing fzf's own ctrl+r, set up by `source <(fzf --zsh)` above). Shows each
# distinct command once (its most recent run), and previews its directory, time, exit status and output. Press enter to
# insert the command at the cursor (not run it), so e.g. `cmd1 && <ctrl+r>` can find cmd2 to follow cmd1. The search
# starts empty, rather than with what's already typed (unlike fzf's ctrl+r).
if (( $+commands[cmdlog] )); then
  cmdlog-history-widget() {
    # Whether the list starts with its commands coloured like the command line (the preview always is). Off, as
    # colouring takes ~2ms per command, and the history only grows (~13 distinct commands a day, so ~10s for a year's
    # worth), and this would be paid every time the list is (re)loaded. ctrl+t toggles it.
    local colour_rows=0
    # Pressing ctrl+r again toggles between all commands and only those run in the current directory (like atuin), and
    # ctrl+t toggles colouring the list's commands. Both reload the list. The border label shows which directory is
    # shown and whether the list's highlighting is on, and doubles as the toggles' memory of these. (fzf runs this in a
    # new shell, in this directory. The label is set with the `:` form, as the last action, so a directory name
    # containing brackets can't break it. Setting CMDLOG_HIGHLIGHT to nothing stops cmdlog colouring.)
    local toggle=(
      'here=0 plain=0'
      '[[ $FZF_BORDER_LABEL == " all directories"* ]] || here=1'
      '[[ $FZF_BORDER_LABEL == *" · highlighting off " ]] && plain=1'
      '[[ $FZF_KEY == ctrl-r ]] && here=$(( !here )) || plain=$(( !plain ))'
      'if (( here )); then label="${PWD/#$HOME/~}" args=--here; else label="all directories" args=; fi'
      'if (( plain )); then label+=" · highlighting off" env="CMDLOG_HIGHLIGHT= "; else label+=" · highlighting on" env=; fi'
      'echo "reload(${env}cmdlog search $args)+change-border-label: $label "'
    )
    local highlighting=off
    (( colour_rows )) && highlighting=on
    local FZF_OPTS=(  # fzf options specific to this widget, in addition to FZF_DEFAULT_OPTS
      --delimiter=$'\t'  # cmdlog search gives `id<TAB>time<TAB>status<TAB>command`.
      --with-nth=2..  # Hide the id.
      --nth=3..  # Only search the command (fields counted after --with-nth, so the 3rd shown field).
      --accept-nth=1  # Only output the id.
      --height=100%  # Use the whole window (see FZF_CTRL_T_OPTS).
      --ansi  # Preserve colours
      --scheme=history
      --layout=default  # Newest commands nearest the command line
      --preview='cmdlog show {1}'
      --preview-window=up,50%,sharp,wrap
      --border-label=" all directories · highlighting $highlighting "
      --bind="ctrl-r,ctrl-t:transform:${(j:; :)toggle}"
    )
    # cmdlog colours the commands (in the list and the preview) as they're coloured on the command line, using
    # ~/.zsh/highlight-commands.zsh, which needs this shell's context.
    local REPLY context
    _save_highlight_context || return
    context=$REPLY
    {
      # Export for cmdlog, including when run by fzf.
      local -x CMDLOG_HIGHLIGHT="zsh -f ${(q)HOME}/.zsh/highlight-commands.zsh ${(q)context}"
      local id
      id=$(if (( colour_rows )); then cmdlog search; else CMDLOG_HIGHLIGHT= cmdlog search; fi | fzf "${FZF_OPTS[@]}")
      if [[ -n "$id" ]]; then
        LBUFFER+=$(cmdlog get "$id")  # Leaves the cursor after the inserted command
      fi
    } always {
      command rm -f -- $context
    }
    zle reset-prompt
  }

  zle -N cmdlog-history-widget
  # fzf binds ctrl+r in all three of these keymaps, so replace it in all of them (not just the current one).
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
    unset VSCODE_INJECTION  # Otherwise VS Code's script would source this file again.
    source "$CMDLOG_VSCODE_RC"
  fi
fi

# Programs like vim can change the cursor shape and leave it changed when they exit. Ghostty's shell integration resets
# it to a line at each prompt, but VS Code's doesn't, so do that here (\e[5 q = blinking line, matching Ghostty).
if [[ "$TERM_PROGRAM" == vscode ]]; then
  _vscode_reset_cursor_precmd() {
    local cmd_status=$?
    print -n '\e[5 q'
    return $cmd_status  # Leave $? as it was for any later precmd hooks.
  }

  precmd_functions+=(_vscode_reset_cursor_precmd)
fi

# Queue commands to run after the current one. While a command runs, press ctrl+z to suspend it, type the next command
# and press cmd+enter: this adds it to the queue and resumes the suspended command (with `fg`). Once that finishes
# successfully, each queued command runs in turn as if typed (so each gets its own history entry and cmdlog record).
# Ctrl+z works on these too, to queue more. If one fails (or is stopped with ctrl+c), the rest of the queue is dropped.
typeset -ga _queue  # Commands waiting to run, in order
typeset -ga _queue_dropped  # The last queue dropped or cleared, for `requeue` to restore
typeset -gi _queue_follow  # Whether the next queued command should run once the current command succeeds
typeset -gi _queue_starting  # Whether the command about to run is the next one from the queue
typeset -gi _queue_autorun  # Whether the next prompt should run the next queued command instead of waiting for input

# Cmd+enter on an empty line adds nothing, but still resumes the suspended command (or starts the queue if there's no
# job left to wait for, e.g. after killing it).
queue-command() {
  [[ -n "${BUFFER//[[:space:]]/}" ]] && _queue+=("$BUFFER")
  if (( $#jobstates )); then
    if (( $#_queue )); then
      zle -I
      print -r -- "Queued: ${(j: → :)_queue}"
    fi
    BUFFER=fg
  elif (( $#_queue )); then
    BUFFER=$_queue[1]
    shift _queue
    _queue_starting=1
  else
    return
  fi
  zle accept-line
}

zle -N queue-command
bindkey $'\e[13;9u' queue-command # custom bound cmd+enter to this escape sequence in my Ghostty and VS Code configs

# Clear the queue manually, printing what was dropped.
unqueue() {
  (( $#_queue )) || return 0
  print -r -- "Queue cleared (\`requeue\` restores it): ${(j: → :)_queue}"
  _queue_dropped=("${_queue[@]}")
  _queue=()
}

# Put the last dropped queue back (ahead of anything queued since), and carry on with it once the suspended
# job finishes, or straight away if there's none. E.g. after a queued command fails, fix the problem and run
# `<failed command> && requeue` to retry it and continue with the queue you had previously set up.
requeue() {
  if (( ! $#_queue_dropped )); then
    print -r -- "requeue: nothing to restore" >&2
    return 1
  fi
  _queue=("${_queue_dropped[@]}" "${_queue[@]}")
  _queue_dropped=()
  (( $#jobstates )) || _queue_autorun=1
}

# Run just before each command, with $1 as the command exactly as typed. Only follow the queue after a queued command
# or one that resumes a job (`fg`, `%1` etc), so e.g. killing the suspended job doesn't start the queue.
_queue_preexec() {
  if (( _queue_starting )) || [[ "$1" == (fg|fg[[:space:]]*|%*) ]]; then
    _queue_follow=1
  else
    _queue_follow=0
  fi
  _queue_starting=0
}

_queue_precmd() {
  local cmd_status=$?
  if (( _queue_follow && $#_queue )); then
    if _is_suspended_status $cmd_status; then
      :  # Suspended again, so keep the queue for when it's resumed.
    elif (( cmd_status == 0 )); then
      _queue_autorun=1
    else
      print -r -- "Queue dropped (exit status $cmd_status, \`requeue\` restores it): ${(j: → :)_queue}"
      _queue_dropped=("${_queue[@]}")
      _queue=()
    fi
  fi
  _queue_follow=0
  (( $#_queue && ! _queue_autorun )) && print -r -- "Queued: ${(j: → :)_queue}"
  return $cmd_status  # Leave $? as it was for any later precmd hooks.
}

# Run when each prompt starts accepting input, to run the next queued command if _queue_precmd said to.
_queue_line_init() {
  (( _queue_autorun )) || return 0  # Must succeed, or add-zle-hook-widget skips later line-init hooks (e.g. Ghostty's).
  _queue_autorun=0
  BUFFER=$_queue[1]
  shift _queue
  _queue_starting=1
  zle accept-line
}

preexec_functions+=(_queue_preexec)
precmd_functions+=(_queue_precmd)
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init _queue_line_init

# Auto-pair quotes and brackets (typing " inserts "", typing the closing " skips over it, backspace between "" deletes
# both), after `brew install zsh-autopair`. It normally binds those keys (and backspace) itself, which would replace the
# selection-aware typing/backspace widgets below, so stop it binding anything and call its widgets from those instead.
# Its fallback widgets are set to zle's own, since mine (which would otherwise be picked up) call autopair's.
AUTOPAIR_INHIBIT_INIT=1
AUTOPAIR_SPC_WIDGET=self-insert
AUTOPAIR_BKSPC_WIDGET=backward-delete-char
source /opt/homebrew/share/zsh-autopair/autopair.zsh
zle -N autopair-insert
zle -N autopair-close
zle -N autopair-delete

# The shortcuts below make editing the current terminal command resemble the behaviour of non-terminal text editors.
# They are coded based off either:
#   - The exact key sequences Ghostty & VS Code send when pressing the shortcuts at the time of writing (so far, both
#     always agree with each other, but may not work with other terminals/configs).
#   - For key sequences intercepted by the app/terminal before reaching the command-line program, explicitly provided
#     keybindings in VS Code's keybindings.json and Ghostty's config.ghostty

# Do not consider '/' as part of a word (word splitting is not impacted). E.g. if command populated with
# folder/subfolder/file123.txt, deleting word becomes folder/subfolder/.
WORDCHARS=${WORDCHARS//\//}

# Shift+left: select previous character.
select-backward-char() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  zle backward-char
}

zle -N select-backward-char
bindkey $'\e[1;2D' select-backward-char

# Shift+right: select next character.
select-forward-char() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  zle forward-char
}

zle -N select-forward-char
bindkey $'\e[1;2C' select-forward-char

# Alt+shift+left: select previous word.
select-backward-word() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  zle backward-word
}

zle -N select-backward-word
bindkey $'\e[1;4D' select-backward-word

# Alt+shift+right: select next word.
select-forward-word() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  zle forward-word
}

zle -N select-forward-word
bindkey $'\e[1;4C' select-forward-word

# Cmd+shift+left: select to beginning of current line.
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

# Cmd+shift+right: select to end of current line.
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

# Shift+up: select up a line (or to the start of the command if already on the first line).
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

# Shift+down: select down a line (or to the end of the command if already on the last line).
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

# Cmd+shift+up: select to beginning of the whole command.
select-to-beginning-of-command() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  CURSOR=0
}

zle -N select-to-beginning-of-command
bindkey $'\e[1;10A' select-to-beginning-of-command

# Cmd+shift+down: select to end of the whole command.
select-to-end-of-command() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
  fi
  REGION_ACTIVE=1
  CURSOR=${#BUFFER}
}

zle -N select-to-end-of-command
bindkey $'\e[1;10B' select-to-end-of-command

# Delete the active selection (helper for the widgets below).
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

# Backspace: delete selection if there is one, otherwise delete previous character.
delete-selection-or-backspace() {
  if (( REGION_ACTIVE )); then
    delete-active-selection
    zle redisplay
  else
    zle autopair-delete  # backward-delete-char, but also deletes the closing half of an empty pair, e.g. `"|"`.
  fi
}

zle -N delete-selection-or-backspace
bindkey '^?' delete-selection-or-backspace

# Typing: delete selection if there is one, then insert the typed character (auto-paired, if it's a quote or bracket).
self-insert-or-replace-selection() {
  if (( REGION_ACTIVE )); then
    delete-active-selection
  fi
  if [[ -n ${AUTOPAIR_PAIRS[$KEYS]} ]]; then
    zle autopair-insert  # Opening character (quotes, brackets, and space, which pairs to { | } inside brackets)
  elif (( ${${(v)AUTOPAIR_PAIRS}[(Ie)$KEYS]} )); then
    zle autopair-close  # Closing bracket
  else
    zle self-insert
  fi
}

zle -N self-insert-or-replace-selection
bindkey -R ' '-'~' self-insert-or-replace-selection  # Printable ASCII characters

# Left: collapse the selection if there is one, otherwise move cursor left by one character.
left-or-cancel-selection() {
  if (( REGION_ACTIVE )); then
    # Collapse to the left edge of the selection.
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

# Right: collapse the selection if there is one, otherwise move cursor right by one character.
right-or-cancel-selection() {
  if (( REGION_ACTIVE )); then
    # Collapse to the right edge of the selection.
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

# Alt+left: move back one word, cancelling any selection.
backward-word-cancel-selection() {
  REGION_ACTIVE=0
  zle backward-word
}

zle -N backward-word-cancel-selection
bindkey $'\eb' backward-word-cancel-selection

# Alt+right: move forward one word, cancelling any selection.
forward-word-cancel-selection() {
  REGION_ACTIVE=0
  zle forward-word
}

zle -N forward-word-cancel-selection
bindkey $'\ef' forward-word-cancel-selection

# Cmd+left: move to start of line, cancelling any selection.
beginning-of-line-cancel-selection() {
  REGION_ACTIVE=0
  zle beginning-of-line
}

zle -N beginning-of-line-cancel-selection
bindkey $'^A' beginning-of-line-cancel-selection

# Cmd+right: move to end of line, cancelling any selection.
end-of-line-cancel-selection() {
  REGION_ACTIVE=0
  zle end-of-line
}

zle -N end-of-line-cancel-selection
bindkey $'^E' end-of-line-cancel-selection

# Up: cancel any selection, then move up a line (or to the previous history entry if on the first line).
up-cancel-selection() {
  REGION_ACTIVE=0
  zle up-line-or-history
}

zle -N up-cancel-selection
bindkey $'\e[A' up-cancel-selection
bindkey $'\eOA' up-cancel-selection

# Down: cancel any selection, then move down a line (or to the next history entry if on the last line).
down-cancel-selection() {
  REGION_ACTIVE=0
  zle down-line-or-history
}

zle -N down-cancel-selection
bindkey $'\e[B' down-cancel-selection
bindkey $'\eOB' down-cancel-selection

# Cmd+up: move to start of the whole command (not just the current line), cancelling any selection.
beginning-of-command() {
  REGION_ACTIVE=0
  CURSOR=0
}

zle -N beginning-of-command
bindkey $'\e[1;9A' beginning-of-command

# Cmd+down: move to end of the whole command, cancelling any selection.
end-of-command() {
  REGION_ACTIVE=0
  CURSOR=${#BUFFER}
}

zle -N end-of-command
bindkey $'\e[1;9B' end-of-command

# Cmd+backspace: delete from cursor to beginning of current line (regardless of active selection).
delete-backward-line() {
  local line_start=${BUFFER[1,$CURSOR]##*$'\n'}
  local count=${#line_start}
  if (( count > 0 )); then
    # Computed before assigning BUFFER, since that clamps CURSOR to the new length if the cursor was at the end.
    local target=$(( CURSOR - count ))
    BUFFER="${BUFFER[1,$target]}${BUFFER[$((CURSOR + 1)),-1]}"
    CURSOR=$target
  fi
}

zle -N delete-backward-line
bindkey $'^U' delete-backward-line

# Cmd+c: copy active selection to clipboard. In Ghostty / VS Code, I actually only send if press cmd+shift+c, because
# cmd+c is already used by them to mean copy TERMINAL's selection (e.g. following mouse drag) rather than ZSH's.
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

# Cmd+x: cut active selection to clipboard.
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

# Cmd+e: edit the command line in $EDITOR. Zsh's temp file ends in .zsh, so Vim highlights it as zsh. 
# Saving and quitting puts the edited text back on the command line, without running it. 
# With a selection active, only the selection is edited.
# Vim then colours it exactly as the command line is coloured (see ~/.vim/plugin/zsh-command-line.vim), given this
# shell's context in $ZSH_HIGHLIGHT_CONTEXT. Vim starts in insert mode at the cursor (see
# ~/.vim/plugin/insert-at-cursor.vim).
#
# Vim leaves the terminal's default cursor shape (a block in Ghostty), so put back the line the prompt has (as in
# _vscode_reset_cursor_precmd).
autoload -Uz edit-command-line
edit-command-line-highlighted() {
  local REPLY
  if ! _save_highlight_context; then
    edit-command-line
    print -n '\e[5 q'
    return
  fi
  local context=$REPLY
  {
    local -x ZSH_HIGHLIGHT_CONTEXT=$context
    edit-command-line
  } always {
    command rm -f -- $context
    print -n '\e[5 q'
  }
}

zle -N edit-command-line-highlighted
bindkey $'\e[101;9u' edit-command-line-highlighted

# Bind redo (undo is already the response to '^_', so needs no binding).
bindkey '^[/' redo

# Highlight the syntax of the command being typed. This must stay at the very end of this file
# (zsh-syntax-highlighting's docs require it to be sourced after everything else that defines zle widgets).
source ~/.zsh/syntax-highlighting.zsh
