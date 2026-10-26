# Syntax highlighting of the command being typed, with zsh-syntax-highlighting (after `brew install zsh-syntax-highlighting`).
# Sourced at the very end of .zshrc (the plugin's docs require it to be sourced after everything else that defines zle
# widgets), and also by highlight-commands.zsh, which colours commands the same way for cmdlog's ctrl+r.

zle_highlight=(
  'default:fg=#cdd6f4' # Zsh default colour (fallback for anything zsh-syntax-highlighting doesn't colour)
  'region:none' # the selection: coloured by my selection highlighter below instead
)
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
ZSH_HIGHLIGHT_STYLES[selection]='bg=#45475a' # surface 1 (as Vim's selection), added to the selected text's own style
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

# Give the selection a background, keeping the syntax colours of the text in it, as VS Code and Vim do. Zsh's own selection
# highlighting (zle_highlight's region) can't do this: zle draws each character in the style of the last highlight covering
# it, rather than combining them, so a background-only highlight would also turn the selected text plain. Hence zsh's default
# for it is to invert the colours instead. This highlighter runs last, and redraws each selected character in the style the
# other highlighters left it in, plus the background
_zsh_highlight_highlighter_selection_predicate() { true } # the selection can change without the command line changing
_zsh_highlight_highlighter_selection_paint() {
  emulate -L zsh
  (( REGION_ACTIVE )) || return
  # The selection's bounds, worked out as zsh-syntax-highlighting does for zle_highlight's region
  integer min max i
  if (( MARK > CURSOR )); then
    min=$CURSOR max=$MARK
  else
    min=$MARK max=$CURSOR
  fi
  if (( REGION_ACTIVE == 1 )); then
    [[ $KEYMAP == vicmd ]] && (( max++ ))
  elif (( REGION_ACTIVE == 2 )); then # a whole-line selection (vi's V), not including the newline
    (( min = ${BUFFER[(Ib:min:)$'\n']} ))
    (( max = ${BUFFER[(ib:max:)$'\n']} - 1 ))
  fi
  # The style of each character, from the highlighters before this one (the last highlight covering a character wins)
  local highlighter entry style
  local -a fields styles
  for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do
    [[ $highlighter == selection ]] && break
    for entry in "${(@P)${:-_zsh_highlight__highlighter_${highlighter}_cache}}"; do # entries are "start end style ..."
      fields=(${(s: :)entry})
      for (( i = (fields[1] > min ? fields[1] : min) + 1; i <= (fields[2] < max ? fields[2] : max); i++ )); do
        styles[i]=${fields[3]%,}
      done
    done
  done
  for (( i = min + 1; i <= max; i++ )); do
    style=${styles[i]:-none}
    [[ $style == none ]] && style=${${zle_highlight[(r)default:*]#default:}:-none}
    region_highlight+=("$(( i - 1 )) $i ${style/#none/},$ZSH_HIGHLIGHT_STYLES[selection], memo=zsh-syntax-highlighting")
  done
}

# after main, so they can override main's colours (and selection last, as it needs everything else's colours)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main pathunderline arithmetic parameter selection)
