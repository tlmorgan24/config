# Usage: `zsh -f highlight-commands.zsh [--ranges] <context file>`
#
# Colour commands as zsh-syntax-highlighting colours them on the command line (using syntax-highlighting.zsh), for
# cmdlog's ctrl+r (see cmdlog-history-widget in .zshrc) and for Vim when editing the command line with cmd+e (see
# edit-command-line-highlighted in .zshrc, and ~/.vim/plugin/zsh-command-line.vim).
#
# The context file should hold the aliases, function names and options (as zsyh_user_options) of the interactive shell,
# as they decide how commands are coloured (e.g. without an alias, it's an unknown command, so red). See
# _save_highlight_context in .zshrc.
#
# Without --ranges, read `<directory>\0<command>\0` pairs on stdin, and for each print the coloured command (as text
# with escape codes) followed by `\0`. Paths in the command are looked up relative to the directory (as when it ran).
# Each line of a coloured command ends with a reset (`\e[0m`), so the lines can be shown separately.
#
# With --ranges, read each command on stdin as a line holding its number of lines, then those lines. Paths in it are
# looked up relative to the current directory. For each, print a line holding its number of lines again, then the
# ranges of characters drawn in the same style, each as ` <line>:<start>:<end>:<style>`. The line counts from 1, start
# and end count characters within the line from 0 (end not included), and the style is a zle highlight spec (e.g.
# `fg=#cba6f7,italic`, or `none`). Every character except the newlines is in a range.

source ${0:A:h}/syntax-highlighting.zsh

# Put the escape code for a zle highlight spec (e.g. "fg=#cba6f7,underline") in $REPLY.
_spec_to_sgr() {
  emulate -L zsh -o extended_glob
  local part colour codes=
  local -A attribute=(bold 1 italic 3 underline 4 standout 7)
  local -A named=(black 0 red 1 green 2 yellow 3 blue 4 magenta 5 cyan 6 white 7)
  for part in ${(s:,:)1}; do
    case $part in
      ([fb]g=*)
        colour=${part#*=}
        [[ $part == f* ]] && codes+=';3' || codes+=';4'
        if [[ $colour == '#'[[:xdigit:]](#c6) ]]; then
          codes+="8;2;$(( 16#${colour[2,3]} ));$(( 16#${colour[4,5]} ));$(( 16#${colour[6,7]} ))"
        elif [[ $colour == <0-255> ]]; then
          codes+="8;5;$colour"
        else
          codes+=${named[$colour]:-9}  # 9 = the terminal's default colour
        fi ;;
      (*) (( $+attribute[$part] )) && codes+=";$attribute[$part]" ;;
    esac
  done
  REPLY=$'\e[0'$codes'm'
}

# Put the style of each character of $BUFFER in $styles (both the caller's), as zle would draw it. Run the highlighters
# as zsh-syntax-highlighting does (each one's results go in a cache that later ones can read), and give each character
# the style of the last highlight covering it (as zle does), or zle_highlight's default if none does.
_highlight_styles() {
  local highlighter entry
  local default=${${zle_highlight[(r)default:*]#default:}:-none}
  local -a fields
  local -i i
  styles=()
  for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do
    region_highlight=()
    _zsh_highlight_highlighter_${highlighter}_paint
    typeset -ga _zsh_highlight__highlighter_${highlighter}_cache
    set -A _zsh_highlight__highlighter_${highlighter}_cache "${region_highlight[@]}"
    for entry in $region_highlight; do  # Entries are "start end style ...".
      fields=(${(s: :)entry})
      for (( i = fields[1] + 1; i <= fields[2] && i <= $#BUFFER; i++ )); do styles[i]=${fields[3]%,}; done
    done
  done
  for (( i = 1; i <= $#BUFFER; i++ )); do
    [[ ${styles[i]:-none} == none ]] && styles[i]=$default
  done
}

# Colour the commands read, as text with escape codes (see the usage above).
_highlight_commands() {
  emulate -L zsh
  # zle's own variables, which the highlighters read
  local BUFFER PREBUFFER= CURSOR REGION_ACTIVE=0
  local dir style previous out REPLY
  local -a styles
  local -A sgr_of  # Cache of _spec_to_sgr's results
  local -i i
  typeset -ga region_highlight
  while IFS= read -r -d '' dir && IFS= read -r -d '' BUFFER; do
    builtin cd -q -- $dir 2>/dev/null || builtin cd -q /
    CURSOR=$#BUFFER
    _highlight_styles
    out= previous=
    for (( i = 1; i <= $#BUFFER; i++ )); do
      if [[ $BUFFER[i] == $'\n' ]]; then
        out+=$'\e[0m\n' previous=
        continue
      fi
      style=$styles[i]
      if [[ $style != $previous ]]; then
        (( $+sgr_of[$style] )) || { _spec_to_sgr $style; sgr_of[$style]=$REPLY }
        out+=$sgr_of[$style] previous=$style
      fi
      out+=$BUFFER[i]
    done
    print -rn -- $out$'\e[0m\0'
  done
}

# Print the ranges of each command read that are drawn in the same style (see the usage above).
_highlight_ranges() {
  emulate -L zsh
  # zle's own variables, which the highlighters read
  local BUFFER PREBUFFER= CURSOR REGION_ACTIVE=0
  local count text previous out
  local -a styles lines
  local -i i row col start
  typeset -ga region_highlight
  while IFS= read -r count; do
    lines=()
    for (( i = 0; i < count; i++ )); do
      IFS= read -r text || return
      lines+=("$text")
    done
    BUFFER=${(pj:\n:)lines}
    CURSOR=$#BUFFER
    _highlight_styles
    out=$count previous= row=1 col=0 start=0
    for (( i = 1; i <= $#BUFFER; i++ )); do
      if [[ $BUFFER[i] == $'\n' ]]; then
        [[ -n $previous ]] && out+=" $row:$start:$col:$previous"
        (( row++, col = 0 ))
        previous=
        continue
      fi
      if [[ $styles[i] != $previous ]]; then
        [[ -n $previous ]] && out+=" $row:$start:$col:$previous"
        previous=$styles[i] start=$col
      fi
      (( col++ ))
    done
    [[ -n $previous ]] && out+=" $row:$start:$col:$previous"
    print -r -- $out
  done
}

# Chosen before the context is read, so its aliases can't change how this is read.
if [[ $1 == --ranges ]]; then
  shift
  _highlight_run=_highlight_ranges
else
  _highlight_run=_highlight_commands
fi
# The context comes last, so its aliases can't change how the code above is read.
[[ -r $1 ]] && source $1
# zsh-syntax-highlighting runs with zsh's default options, so reads the user's from this (normally filling it itself).
(( $+zsyh_user_options )) || typeset -A zsyh_user_options=("${(kv)options[@]}")
$_highlight_run
