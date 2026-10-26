# Colours commands as zsh-syntax-highlighting colours them on the command line (using syntax-highlighting.zsh), as text with
# escape codes, for cmdlog's ctrl+r (see cmdlog-history-widget in .zshrc).
#
# Usage: zsh -f highlight-commands.zsh <context file>
# The context file should hold the aliases, function names and options (as zsyh_user_options) of the interactive shell, as
# they decide how commands are coloured (e.g. without an alias, it's an unknown command, so red).
# Reads <directory>\0<command>\0 pairs on stdin, and for each prints the coloured command followed by \0. Paths in the command
# are looked up relative to the directory (as when it ran).
# Each line of a coloured command ends with a reset (\e[0m), so the lines can be shown separately.

source ${0:A:h}/syntax-highlighting.zsh

# Escape code for a zle highlight spec (e.g. "fg=#cba6f7,underline"), in $REPLY
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
          codes+=${named[$colour]:-9} # 9 = the terminal's default colour
        fi ;;
      (*) (( $+attribute[$part] )) && codes+=";$attribute[$part]" ;;
    esac
  done
  REPLY=$'\e[0'$codes'm'
}

_highlight_commands() {
  emulate -L zsh
  # zle's own variables, which the highlighters read
  local BUFFER PREBUFFER= CURSOR REGION_ACTIVE=0
  local highlighter entry dir style previous out REPLY
  local -a fields styles
  local -A sgr_of # cache of _spec_to_sgr's results
  local -i i
  local default=${${zle_highlight[(r)default:*]#default:}:-none}
  typeset -ga region_highlight
  while IFS= read -r -d '' dir && IFS= read -r -d '' BUFFER; do
    builtin cd -q -- $dir 2>/dev/null || builtin cd -q /
    CURSOR=$#BUFFER
    # Run the highlighters as zsh-syntax-highlighting does (each one's results go in a cache that later ones can read), and
    # work out the style of each character (the last highlight covering it wins, as in zle)
    styles=()
    for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do
      region_highlight=()
      _zsh_highlight_highlighter_${highlighter}_paint
      typeset -ga _zsh_highlight__highlighter_${highlighter}_cache
      set -A _zsh_highlight__highlighter_${highlighter}_cache "${region_highlight[@]}"
      for entry in $region_highlight; do # entries are "start end style ..."
        fields=(${(s: :)entry})
        for (( i = fields[1] + 1; i <= fields[2] && i <= $#BUFFER; i++ )); do styles[i]=${fields[3]%,}; done
      done
    done
    out= previous=
    for (( i = 1; i <= $#BUFFER; i++ )); do
      if [[ $BUFFER[i] == $'\n' ]]; then
        out+=$'\e[0m\n' previous=
        continue
      fi
      style=${styles[i]:-none}
      [[ $style == none ]] && style=$default
      if [[ $style != $previous ]]; then
        (( $+sgr_of[$style] )) || { _spec_to_sgr $style; sgr_of[$style]=$REPLY }
        out+=$sgr_of[$style] previous=$style
      fi
      out+=$BUFFER[i]
    done
    print -rn -- $out$'\e[0m\0'
  done
}

# The context comes last, so its aliases can't change how the code above is read
[[ -r $1 ]] && source $1
# zsh-syntax-highlighting runs with zsh's default options, so reads the user's from this (normally filling it itself)
(( $+zsyh_user_options )) || typeset -A zsyh_user_options=("${(kv)options[@]}")
_highlight_commands
