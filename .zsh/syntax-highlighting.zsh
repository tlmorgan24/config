# Syntax highlighting of the command being typed, with zsh-syntax-highlighting (after
# `brew install zsh-syntax-highlighting`). Sourced at the very end of .zshrc (the plugin's docs require it to be sourced
# after everything else that defines zle widgets), and also by highlight-commands.zsh, which colours commands the same
# way for cmdlog's ctrl+r.

zle_highlight=(
  'default:fg=#cdd6f4'  # Zsh default colour (fallback for anything zsh-syntax-highlighting doesn't colour)
  'region:none'  # The selection, coloured by my selection highlighter below instead
  'paste:none'  # Pasted/yanked text, likewise
)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Colours are from the Catppuccin Mocha palette, assigned as per Catppuccin's style guide
# (https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md).

# Defaults
ZSH_HIGHLIGHT_STYLES[default]='fg=#cdd6f4'  # Text: positional arguments etc
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#cdd6f4'  # Text: command names the styles below don't cover

# Commands: blue (the guide's colour for functions)
ZSH_HIGHLIGHT_STYLES[command]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[function]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#89b4fa'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#89b4fa,italic'  # sudo, exec, etc
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#fab387,italic'  # Peach: a directory typed as a command (to cd into it)

# Control flow: mauve (the guide's colour for keywords). reserved-word covers if, for, do, etc (and return, break,
# continue and in, via my keywords highlighter below).
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#cba6f7'

# Options: peach
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#fab387'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#fab387'

# Operators: sky
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#89dceb'  # `>` `<` `>>` etc
# `|` `&&` `||` `&` (as logical operators are in other languages). `;` is recoloured below.
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#89dceb'
ZSH_HIGHLIGHT_STYLES[assign-operator]='fg=#89dceb'  # The `=` in `var=value` (used by my separators highlighter below)
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#fab387'  # Peach (numbers): the 2 in `2>&1`
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#cdd6f4'  # Text: the fd in `{fd}>file`

# Strings: green
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#a6e3a1'  # `$'...'`
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#a6e3a1'  # `"$(command)"`

# Variables: rosewater (the guide's colour for macros, which like variables get replaced by something else before
# running)
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#f5e0dc'  # `$var` inside `"..."`
ZSH_HIGHLIGHT_STYLES[parameter]='fg=#f5e0dc'  # `$var` elsewhere (used by my parameter and arithmetic highlighters below)
# Positional parameters (`$1`, `${1}`, `$@`): maroon, italic (the guide's colour for parameters, styled as VS Code does
# them in all languages). Used by my parameter and arithmetic highlighters below.
ZSH_HIGHLIGHT_STYLES[positional-parameter]='fg=#eba0ac,italic'

# Escape sequences and patterns: pink
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#f5c2e7'  # `\"` `\$` etc inside `"..."`
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#f5c2e7'  # `\n` `\t` etc inside `$'...'`
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#f5c2e7'  # `''` inside `'...'` (with the RC_QUOTES option)
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#f5c2e7'  # `*` `?` `[...]`

# Delimiters: overlay 2
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#9399b2'  # The backquotes around a backquoted command
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#9399b2'  # The `$( )` around `$(command)`
# The `$( )` around `$(command)` in an unquoted argument
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#9399b2'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#9399b2'  # The `$( )` around `"$(command)"`
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#9399b2'  # The `<( )` around `<(command)`
# `;` (as in other languages), which the plugin colours as a commandseparator (used by my separators highlighter below)
ZSH_HIGHLIGHT_STYLES[statement-terminator]='fg=#9399b2'

# Brackets, by how deeply they're nested: the guide's rainbow colours, as VS Code's bracket pair colouring uses (used by
# my rainbow highlighter below). Deeper brackets start again from the first.
ZSH_HIGHLIGHT_STYLES[bracket-depth-1]='fg=#f38ba8'  # Red
ZSH_HIGHLIGHT_STYLES[bracket-depth-2]='fg=#fab387'  # Peach
ZSH_HIGHLIGHT_STYLES[bracket-depth-3]='fg=#f9e2af'  # Yellow
ZSH_HIGHLIGHT_STYLES[bracket-depth-4]='fg=#a6e3a1'  # Green
ZSH_HIGHLIGHT_STYLES[bracket-depth-5]='fg=#74c7ec'  # Sapphire
ZSH_HIGHLIGHT_STYLES[bracket-depth-6]='fg=#cba6f7'  # Mauve
ZSH_HIGHLIGHT_STYLES[bracket-unexpected]='fg=#eba0ac'  # Maroon: a `)` `]` or `}` that doesn't close anything (as in VS Code)

# Paths: text, underlined
ZSH_HIGHLIGHT_STYLES[path]='fg=#cdd6f4,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#cdd6f4,underline'  # A path that's still being typed
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#cba6f7,underline'  # Mauve: the `/` in paths
# Mauve: the `/` in paths for a path that's still being typed
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#cba6f7,underline'

# Arithmetic, i.e. inside `(( ))` and `$(( ))`. Only the arithmetic-expansion style is the plugin's (which it applies to
# a whole `$(( ))`); the others are used by my arithmetic highlighter below. arithmetic-expansion must stay "none", as
# that highlighter finds the `$(( ))`s by it.
ZSH_HIGHLIGHT_STYLES[arithmetic-expansion]='none'
# Overlay 2: the `$(( ))` around `$((1 + 1))` (`(( ))` are reserved-words).
ZSH_HIGHLIGHT_STYLES[arithmetic-delimiter]='fg=#9399b2'
ZSH_HIGHLIGHT_STYLES[arithmetic-bracket]='fg=#9399b2'  # Overlay 2
ZSH_HIGHLIGHT_STYLES[arithmetic-operator]='fg=#89dceb'  # Sky: `+` `-` `*` `/` `==` etc
ZSH_HIGHLIGHT_STYLES[arithmetic-number]='fg=#fab387'  # Peach

# Other
#
# `var=value`: "none" shows as text, like "fg=#cdd6f4" would, but lets my separators highlighter below tell an
# assignment apart from an argument that just contains an `=` (`echo a=b`).
ZSH_HIGHLIGHT_STYLES[assign]='none'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#cba6f7'  # Mauve: `!!` `!$` etc
ZSH_HIGHLIGHT_STYLES[comment]='fg=#9399b2,italic'  # Overlay 2, italic as in VS Code
ZSH_HIGHLIGHT_STYLES[selection]='bg=#45475a'  # Surface 1 (as Vim's selection), added to the selected text's own style
# Surface 0, fainter than the selection, added to pasted/yanked text's own style
ZSH_HIGHLIGHT_STYLES[paste]='bg=#313244'

# Errors: red
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8'  # E.g. a command that doesn't exist
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#f38ba8'

# Underline quoted paths too. zsh-syntax-highlighting recognises "/etc/hosts" as a path, but colours it as a string
# afterwards, which replaces the path's underline rather than adding to it. This highlighter runs straight after the
# main one and redraws any part of a path that was recoloured (e.g. a quoted string) in that colour plus underline. It
# reads the main highlighter's results from the plugin's internal (undocumented) cache variable, so a plugin upgrade
# could stop it working, in which case quoted paths just aren't underlined. Tested with zsh-syntax-highlighting 0.8.0
# and zsh 5.9 (zsh controls the "start end style" format of the cached entries). If an upgrade breaks it, go back to
# 0.8.0 and `brew pin zsh-syntax-highlighting`.
_zsh_highlight_highlighter_pathunderline_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_pathunderline_paint() {
  emulate -L zsh
  local entry
  local -a fields paths
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
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
  # Re-add the `/`s' own highlights last, as the redrawn strings above would otherwise cover them.
  region_highlight+=($separators)
}

# Colour the insides of `(( ))` and `$(( ))` (numbers, operators, etc), which zsh-syntax-highlighting leaves uncoloured.
# Like the pathunderline highlighter, this runs after the main one and relies on its cache: it finds (( )) commands by
# their (( and )) entries, and $(( )) expansions by their arithmetic-expansion entries, then colours what's between.
_zsh_highlight_highlighter_arithmetic_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_arithmetic_paint() {
  emulate -L zsh
  local entry
  local -a fields opens closes
  local -A expansions  # start -> finish
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    case $BUFFER[fields[1]+1,fields[2]] in
      ('((') opens+=($fields[1]) ;;  # A `(( ))` command, including in a for loop
      ('))') closes+=($fields[1]) ;;
      ('$(('*)
        # A `$(( ))` expansion. If another entry starts at the same place, it's for a longer argument that the expansion
        # is only the start of.
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
    # Highlight the `((`, as the main highlighter doesn't for a for loop's `((`.
    _zsh_highlight_add_highlight $start $(( start + 2 )) reserved-word
    if (( finish < 0 )); then
      # Unclosed, so its contents run to the end of the line.
      _zsh_highlight_arithmetic_contents $(( start + 3 )) $#BUFFER
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

# Colour the numbers, variables, operators and brackets in `$BUFFER[$1,$2]`. Anything else (like a `$(command)` inside)
# is left as the main highlighter coloured it.
_zsh_highlight_arithmetic_contents() {
  local -i i=$1 j depth
  local REPLY
  while (( i <= $2 )); do
    case $BUFFER[i] in
      ([0-9])  # E.g. 42, 1.5, 0x1f, 16#ff
        j=i; while (( j < $2 )) && [[ $BUFFER[j+1] == [[:alnum:]_.#] ]]; do (( j++ )); done
        _zsh_highlight_add_highlight $(( i - 1 )) $j arithmetic-number
        i=j ;;
      ([[:alpha:]_$])
        if [[ $BUFFER[i] == '$' && ( $BUFFER[i+1] == '{' || $BUFFER[i+1] == '(' && $BUFFER[i+2] != '(' ) ]]; then
          # `${param}` or `$(command)`: skip to its end.
          for (( j = i + 1, depth = 0; j <= $2; j++ )); do
            [[ $BUFFER[j] == [\({] ]] && (( depth++ ))
            [[ $BUFFER[j] == [\)}] ]] && (( --depth == 0 )) && break
          done
          i=j
        elif [[ $BUFFER[i] == '$' && $BUFFER[i+1] == '(' ]]; then
          :  # A nested `$(( ))`: the loop over expansions colours its delimiters, so just move past the `$`.
        else  # A variable, with or without a `$`
          j=i; while (( j < $2 )) && [[ $BUFFER[j+1] == [[:alnum:]_] ]]; do (( j++ )); done
          _zsh_highlight_parameter_style $i $j
          _zsh_highlight_add_highlight $(( i - 1 )) $j $REPLY
          i=j
        fi ;;
      ('`')  # A backquoted command: skip to its end.
        j=i+1; while (( j < $2 )) && [[ $BUFFER[j] != '`' ]]; do (( j++ )); done
        i=j ;;
      ([\(\)]) _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-bracket ;;
      ('!')  # The main highlighter colours a `!` as a history expansion unless it's followed by one of these.
        [[ $BUFFER[i+1] == ['=({'[:blank:]] ]] && _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-operator ;;
      ([-+*/%\<\>=~^\&\|?:,\;]) _zsh_highlight_add_highlight $(( i - 1 )) $i arithmetic-operator ;;
    esac
    (( i++ ))
  done
}

# Colour $variables in arguments, which zsh-syntax-highlighting leaves the same as the rest of the argument (it only
# colours them inside "...", and there only the simplest ones, like `$var` and `${var}`, not `${arr[@]}` or
# `${var:-default}`). Like the highlighters above, this relies on the main highlighter's cache: it looks in the entries
# for plain arguments and "..." strings, skipping any part that has its own entry (a quoted string, a `$(command)`,
# etc), as those are coloured already. A $variable used as a command isn't affected, as the main highlighter colours it
# as whatever command it runs.
_zsh_highlight_highlighter_parameter_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_parameter_paint() {
  emulate -L zsh
  local entry inner REPLY
  local -a fields inner_fields
  local -A covered  # The positions in the argument that have their own entry
  local -i i j depth
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    # The $variables the plugin colours inside "..." include positional parameters, which get their own style.
    if [[ ${fields[3]%,} == $ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument] ]]; then
      _zsh_highlight_parameter_style $(( fields[1] + 1 )) $fields[2]
      [[ $REPLY == positional-parameter ]] && _zsh_highlight_add_highlight $fields[1] $fields[2] $REPLY
      continue
    fi
    # "..." shares its style with '...', so is told apart by its first character.
    [[ ${fields[3]%,} == $ZSH_HIGHLIGHT_STYLES[default] ||
       ${fields[3]%,} == $ZSH_HIGHLIGHT_STYLES[double-quoted-argument] && $BUFFER[fields[1]+1] == '"' ]] || continue
    covered=()
    for inner in $_zsh_highlight__highlighter_main_cache; do
      [[ $inner == $entry ]] && continue
      inner_fields=(${(s: :)inner})
      if (( inner_fields[1] >= fields[1] && inner_fields[2] <= fields[2] )) &&
         [[ ${inner_fields[3]%,} != $ZSH_HIGHLIGHT_STYLES[default] ]]; then
        for (( i = inner_fields[1] + 1; i <= inner_fields[2]; i++ )); do covered[$i]=1; done
      fi
    done
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do
      [[ $BUFFER[i] == '$' ]] && (( ! $+covered[$i] )) || continue
      # Skip an escaped `\$` (one after an odd number of `\`s).
      j=i-1; while (( j > fields[1] )) && [[ $BUFFER[j] == '\' ]]; do (( j-- )); done
      (( (i - 1 - j) % 2 )) && continue
      j=i+1
      case $BUFFER[j] in
        ('{')  # `${...}`: up to the matching `}`
          depth=0
          while (( j < fields[2] )); do
            [[ $BUFFER[j] == '{' ]] && (( depth++ ))
            [[ $BUFFER[j] == '}' ]] && (( --depth == 0 )) && break
            (( j++ ))
          done ;;
        ([[:alpha:]_]) while (( j < fields[2] )) && [[ $BUFFER[j+1] == [[:alnum:]_] ]]; do (( j++ )); done ;;
        ([0-9]) while (( j < fields[2] )) && [[ $BUFFER[j+1] == [0-9] ]]; do (( j++ )); done ;;
        ([*@#?\$!-]) ;;  # Special parameters like `$?` and `$#`
        (*) continue ;;  # Not a variable, e.g. a `$` on its own
      esac
      _zsh_highlight_parameter_style $i $j
      _zsh_highlight_add_highlight $(( i - 1 )) $j $REPLY
      i=j
    done
  done
}

# Put the style for the parameter `$BUFFER[$1,$2]` in $REPLY: positional-parameter for `$1`, `${1}`, `${1:-default}`,
# `$@` etc (as VS Code does), and parameter for any other.
_zsh_highlight_parameter_style() {
  emulate -L zsh -o extended_glob
  [[ $BUFFER[$1,$2] == ('$'([0-9]##|@)|'${'[[:space:]]#[0-9]*) ]] && REPLY=positional-parameter || REPLY=parameter
}

# Colour return, break and continue as keywords (as they are in other languages) rather than as builtins, and the in of
# for/select/foreach/case, which zsh-syntax-highlighting leaves uncoloured. Like the highlighters above, this relies on
# the main highlighter's cache.
_zsh_highlight_highlighter_keywords_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_keywords_paint() {
  emulate -L zsh
  local entry text style
  local -a fields
  local -i expect_in=0  # Whether an in is due (after a for, select, foreach or case)
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    text=$BUFFER[fields[1]+1,fields[2]] style=${fields[3]%,}
    if [[ $style == $ZSH_HIGHLIGHT_STYLES[reserved-word] ]]; then
      [[ $text == (for|select|foreach|case) ]] && expect_in=1 || expect_in=0
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[builtin] && $text == (return|break|continue) ]]; then
      _zsh_highlight_add_highlight $fields[1] $fields[2] reserved-word
    elif (( expect_in )) && [[ $style == $ZSH_HIGHLIGHT_STYLES[default] && $text == in ]]; then
      _zsh_highlight_add_highlight $fields[1] $fields[2] reserved-word
      expect_in=0
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[commandseparator] ]]; then
      expect_in=0
    fi
  done
}

# Colour `;` as punctuation, rather than as an operator like `&&` and `||` (zsh-syntax-highlighting styles them all as
# commandseparators), and the `=` (or `+=`) of an assignment as an operator. Assignments are found by their assign style
# (see above), or as the `name=value` arguments of export, local etc, which the plugin colours as plain arguments. Like
# the highlighters above, this relies on the main highlighter's cache.
_zsh_highlight_highlighter_separators_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_separators_paint() {
  emulate -L zsh -o extended_glob
  local entry text style
  local -a fields match mbegin mend
  local -i declaring=0  # Whether in the arguments of export, local etc
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    text=$BUFFER[fields[1]+1,fields[2]] style=${fields[3]%,}
    if [[ $style == $ZSH_HIGHLIGHT_STYLES[commandseparator] ]]; then
      declaring=0
      # Including case's `;;` `;&` `;|`
      [[ $text == \;* ]] && _zsh_highlight_add_highlight $fields[1] $fields[2] statement-terminator
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[reserved-word] ]]; then
      [[ $text == (export|local|typeset|declare|readonly|integer|float|private) ]] && declaring=1 || declaring=0
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[assign] ]] || { (( declaring )) && [[ $style == $ZSH_HIGHLIGHT_STYLES[default] ]] }; then
      # Match name, or `name[subscript]`, then `=` or `+=`.
      [[ $text == (#b)([[:IDENT:]]##(\[[^]]#\])#)(+|)=* ]] &&
        _zsh_highlight_add_highlight $(( fields[1] + $#match[1] )) $(( fields[1] + $#match[1] + $#match[3] + 1 )) assign-operator
    fi
  done
}

# Colour brackets by how deeply they're nested, as VS Code does (its bracket pair colouring). As in VS Code, brackets in
# strings and comments don't count, nor do those in plain arguments (e.g. in the glob `*.[ch]` or the brace expansion
# `{a,b}`), which VS Code's shell grammar treats as strings, except those of a `${...}` in one, and the `]` of
# `[ ... ]`. Like the highlighters above, this relies on the main highlighter's cache (and the parameter highlighter's,
# for `${...}`).
_zsh_highlight_highlighter_rainbow_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_rainbow_paint() {
  emulate -L zsh
  local entry style text char
  local -a fields stack  # stack: the positions of the brackets still open
  # For each position: whether it's in a string or comment, the style and text of the last entry covering it (the one
  # zle shows), and whether it's in a `${...}`.
  local -a quoted last last_text parameter
  local -i i
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    style=${fields[3]%,} text=$BUFFER[fields[1]+1,fields[2]]
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do
      # Strings (which share one style) and comments, including unclosed strings (styled as errors, so told apart by
      # their first character)
      if [[ $style == ($ZSH_HIGHLIGHT_STYLES[double-quoted-argument]|$ZSH_HIGHLIGHT_STYLES[comment]) ||
            $style == $ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed] && $text == (\'|\"|\$\')* ]]; then
        quoted[i]=1
      fi
      last[i]=$style last_text[i]=$text
    done
  done
  for entry in $_zsh_highlight__highlighter_parameter_cache; do
    fields=(${(s: :)entry})
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do parameter[i]=1; done
  done
  for (( i = 1; i <= $#BUFFER; i++ )); do
    char=$BUFFER[i]
    [[ $char == [\(\)\[\]\{\}] ]] || continue
    (( quoted[i] )) && continue
    [[ $last[i] == $ZSH_HIGHLIGHT_STYLES[default] ]] && (( ! parameter[i] )) && [[ $last_text[i] != ']' ]] && continue
    if [[ $char == [\(\[\{] ]]; then
      stack+=($i)
      _zsh_highlight_add_highlight $(( i - 1 )) $i bracket-depth-$(( ($#stack - 1) % 6 + 1 ))
    elif (( $#stack )) && [[ $BUFFER[stack[-1]]$char == ('()'|'[]'|'{}') ]]; then
      _zsh_highlight_add_highlight $(( i - 1 )) $i bracket-depth-$(( ($#stack - 1) % 6 + 1 ))
      stack[-1]=()
    else
      _zsh_highlight_add_highlight $(( i - 1 )) $i bracket-unexpected
    fi
  done
}

# Give the selection a background, keeping the syntax colours of the text in it, as VS Code and Vim do. Zsh's own
# selection highlighting (zle_highlight's region) can't do this: zle draws each character in the style of the last
# highlight covering it, rather than combining them, so a background-only highlight would also turn the selected text
# plain. Hence zsh's default for it is to invert the colours instead. This highlighter runs last, and redraws each
# selected character in the style the other highlighters left it in, plus the background. Text just pasted or yanked
# gets the same treatment, with a fainter background, in place of zsh's default of inverting it too.
_zsh_highlight_highlighter_selection_predicate() { true }  # The selection can change without the command line changing.

_zsh_highlight_highlighter_selection_paint() {
  emulate -L zsh
  (( REGION_ACTIVE || YANK_ACTIVE )) || return
  # The ranges to give a background, as "start end style", the selection last so it wins where they overlap. lo and hi
  # cover them all.
  integer min max lo=$#BUFFER hi=0 i
  local -a ranges
  if (( YANK_ACTIVE )); then
    (( min = YANK_START < YANK_END ? YANK_START : YANK_END, max = YANK_START + YANK_END - min ))
    ranges+=("$min $max paste")
    (( lo = min < lo ? min : lo, hi = max > hi ? max : hi ))
  fi
  if (( REGION_ACTIVE )); then
    # The selection's bounds, worked out as zsh-syntax-highlighting does for zle_highlight's region
    if (( MARK > CURSOR )); then
      min=$CURSOR max=$MARK
    else
      min=$MARK max=$CURSOR
    fi
    if (( REGION_ACTIVE == 1 )); then
      [[ $KEYMAP == vicmd ]] && (( max++ ))
    elif (( REGION_ACTIVE == 2 )); then  # A whole-line selection (vi's V), not including the newline
      (( min = ${BUFFER[(Ib:min:)$'\n']} ))
      (( max = ${BUFFER[(ib:max:)$'\n']} - 1 ))
    fi
    ranges+=("$min $max selection")
    (( lo = min < lo ? min : lo, hi = max > hi ? max : hi ))
  fi
  # The style of each character, from the highlighters before this one (the last highlight covering a character wins).
  local highlighter entry range style
  local -a fields styles
  for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do
    [[ $highlighter == selection ]] && break
    for entry in "${(@P)${:-_zsh_highlight__highlighter_${highlighter}_cache}}"; do  # Entries are "start end style ...".
      fields=(${(s: :)entry})
      for (( i = (fields[1] > lo ? fields[1] : lo) + 1; i <= (fields[2] < hi ? fields[2] : hi); i++ )); do
        styles[i]=${fields[3]%,}
      done
    done
  done
  for range in $ranges; do
    fields=(${(s: :)range})
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do
      style=${styles[i]:-none}
      [[ $style == none ]] && style=${${zle_highlight[(r)default:*]#default:}:-none}
      region_highlight+=("$(( i - 1 )) $i ${style/#none/},$ZSH_HIGHLIGHT_STYLES[$fields[3]], memo=zsh-syntax-highlighting")
    done
  done
}

# Run these after main, so they can override main's colours (and selection last, as it needs everything else's colours).
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main pathunderline arithmetic parameter keywords separators rainbow selection)
