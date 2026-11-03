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
# my rainbow highlighter below, and the regex one). Deeper brackets start again from the first. Unlike the guide's, they
# don't start with red, so that red only means an error, and end with lavender instead (as set for VS Code too, in its
# settings.json).
ZSH_HIGHLIGHT_STYLES[bracket-depth-1]='fg=#fab387'  # Peach
ZSH_HIGHLIGHT_STYLES[bracket-depth-2]='fg=#f9e2af'  # Yellow
ZSH_HIGHLIGHT_STYLES[bracket-depth-3]='fg=#a6e3a1'  # Green
ZSH_HIGHLIGHT_STYLES[bracket-depth-4]='fg=#74c7ec'  # Sapphire
ZSH_HIGHLIGHT_STYLES[bracket-depth-5]='fg=#cba6f7'  # Mauve
ZSH_HIGHLIGHT_STYLES[bracket-depth-6]='fg=#b4befe'  # Lavender
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

# Regexes, in the arguments of the commands that take Perl-style ones (see my regex highlighter below). Their groups and
# character classes are coloured as brackets (by depth, as above), the variables interpolated into Perl's as Perl
# variables (below), and the `(?#...)` comments as comments.
ZSH_HIGHLIGHT_STYLES[regex-escape]='fg=#f5c2e7'  # Pink (the guide's colour for regex): `\[` `\d` `.` `[:alpha:]` etc
ZSH_HIGHLIGHT_STYLES[regex-operator]='fg=#89dceb'  # Sky: `*` `+?` `{2,3}` `|` `^` `$`, and the `^` and `-` in `[^a-z]`
ZSH_HIGHLIGHT_STYLES[regex-group]='fg=#cba6f7'  # Mauve: the `?:` `?=` `?<name>` `?i` etc in `(?:...)`, and `*SKIP` etc
# Red: what a regex or Perl string can't have, e.g. `(?=` and `\1` in fd, `\d` in sed, `\q` anywhere
ZSH_HIGHLIGHT_STYLES[syntax-error]='fg=#f38ba8'

# sed scripts, in the arguments of sed (also see my regex highlighter below). Their text (e.g. a replacement) is left
# green, as the shell string it's in, and their `{ }` are coloured by depth (as above).
ZSH_HIGHLIGHT_STYLES[sed-command]='fg=#cba6f7'  # Mauve: `s` `d` `p` `y` etc, and the flags of `s` (`g` `I` etc)
ZSH_HIGHLIGHT_STYLES[sed-address]='fg=#fab387'  # Peach (numbers): the `1` `$` `0~2` etc that pick lines
ZSH_HIGHLIGHT_STYLES[sed-operator]='fg=#89dceb'  # Sky: the `,` `!` `~` `+` of addresses
ZSH_HIGHLIGHT_STYLES[sed-reference]='fg=#f5e0dc'  # Rosewater (variables): `&` and `\1` etc in a replacement
ZSH_HIGHLIGHT_STYLES[sed-escape]='fg=#f5c2e7'  # Pink: `\n` `\&` `\/` etc in a replacement, and `\U` `\l` etc
ZSH_HIGHLIGHT_STYLES[sed-delimiter]='fg=#9399b2'  # Overlay 2: the `/`s of `s/.../.../` etc, and `;`
ZSH_HIGHLIGHT_STYLES[sed-label]='fg=#89b4fa'  # Blue (functions): the `loop` of `:loop` and `b loop`

# Perl code, in the arguments of perl and my p and pp functions (also see my regex highlighter below), coloured as the
# shell's own code is above. Its brackets are coloured by depth (as above).
ZSH_HIGHLIGHT_STYLES[perl-default]='fg=#cdd6f4'  # Text: the rest, rather than the green of the shell string it's in
ZSH_HIGHLIGHT_STYLES[perl-keyword]='fg=#cba6f7'  # Mauve: `if` `my` `sub` `return` etc
ZSH_HIGHLIGHT_STYLES[perl-function]='fg=#89b4fa'  # Blue: `print` `split` etc, and subs and methods
ZSH_HIGHLIGHT_STYLES[perl-module]='fg=#f9e2af'  # Yellow (the guide's colour for classes): e.g. `List::Util`
ZSH_HIGHLIGHT_STYLES[perl-variable]='fg=#f5e0dc'  # Rosewater: `$x` `@F` `%h` `$_` `$1` etc, also in strings and regexes
ZSH_HIGHLIGHT_STYLES[perl-number]='fg=#fab387'  # Peach
ZSH_HIGHLIGHT_STYLES[perl-operator]='fg=#89dceb'  # Sky: `=~` `&&` `->` `eq` etc
ZSH_HIGHLIGHT_STYLES[perl-punctuation]='fg=#9399b2'  # Overlay 2: `;` and `,`
ZSH_HIGHLIGHT_STYLES[perl-string]='fg=#a6e3a1'  # Green, including the literal parts of regexes
ZSH_HIGHLIGHT_STYLES[perl-escape]='fg=#f5c2e7'  # Pink: `\n` `\t` `\"` etc in strings
ZSH_HIGHLIGHT_STYLES[perl-comment]='fg=#9399b2,italic'  # Overlay 2, italic
ZSH_HIGHLIGHT_STYLES[perl-quote-operator]='fg=#cba6f7'  # Mauve: `m` `s` `qr` `q` `tr` etc and their flags (`g` `i` etc)
ZSH_HIGHLIGHT_STYLES[perl-delimiter]='fg=#9399b2'  # Overlay 2: the `/`s of `/.../` `s/.../.../` etc

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

# Colour the shell code given to my ff, fr and fl functions (in .zshrc), which they run with eval, as the shell's own
# code, as zsh-syntax-highlighting colours the code in a `$( )`. This wraps the plugin's internal (undocumented)
# function that colours a list of commands, so a plugin upgrade could stop it working (see the pathunderline highlighter
# below for what to do then). Once the plugin's function has coloured the whole command line, it finds the code's words
# among the results (as the regex highlighter below finds regexes), and runs the plugin's function again on the code in
# each, adding the results straight after the word's own. That's only for code that reaches the function as typed (bar
# quotes and backslashes), so e.g. not in `"..."` with a `$f` in, which the shell would expand first. The highlighters
# below then see the code as more commands, as in a `$( )`, and colour it as they colour the rest, e.g. its regexes.
#
# If the arguments of ff, fr or fl change, update _zsh_highlight_code_command to match.
typeset -gA _zsh_highlight_code_words  # The code's words: start -> "end <how many of the results are the word's own>"
typeset -gi _zsh_highlight_code_busy  # Whether the code is being looked for, so the function's own calls are left alone
functions[_zsh_highlight_code_list_plain]=$functions[_zsh_highlight_main_highlighter_highlight_list]

_zsh_highlight_main_highlighter_highlight_list() {
  (( _zsh_highlight_code_busy )) && { _zsh_highlight_code_list_plain "$@"; return }
  local -i ret
  local saved
  {
    _zsh_highlight_code_busy=1
    _zsh_highlight_code_list_plain "$@"
    ret=$? saved=$REPLY
    _zsh_highlight_code_words=()
    # Unless there can't be any, as is quick to rule out
    [[ $BUFFER == *f[frl]* ]] || (( ${#${(M)aliases:#*f[frl]*}} )) && _zsh_highlight_code_expand
    REPLY=$saved
  } always {
    _zsh_highlight_code_busy=0
  }
  return ret
}

# Add the results for the shell code in the arguments of ff, fr and fl to $reply, the results of the plugin's function
# (as "start end style" triples, the style being a name in ZSH_HIGHLIGHT_STYLES), each straight after those of the
# code's word, and note the words in _zsh_highlight_code_words. This runs in the main highlighter's paint function (with
# its options and variables, which the plugin's function needs).
_zsh_highlight_code_expand() {
  local start end_ style word code
  local -a triples=("${reply[@]}") entries found nested positions
  local -i i j k first after
  # The results in the format of the main highlighter's cache (see the other highlighters below), for
  # _zsh_highlight_commands. Each style is the first of it and its fallbacks that's set, as the plugin does.
  for start end_ style in $triples; do
    _zsh_highlight_main_calculate_fallback $style
    for style in $reply; do (( $+ZSH_HIGHLIGHT_STYLES[$style] )) && break; done
    entries+=("$start $end_ $ZSH_HIGHLIGHT_STYLES[$style],")
  done
  _zsh_highlight_commands _zsh_highlight_code_command
  # From the last word to the first, so adding results doesn't move those of the words still to do.
  for word in ${(On)found}; do
    start=${word% *} end_=${word#* }
    first=${entries[(i)$start $end_ *]}
    for (( after = first + 1; after <= $#entries; after++ )); do (( ${entries[after]%% *} < end_ )) || break; done
    _zsh_highlight_regex_unquote $start $end_ || continue
    code=$REPLY positions=("${reply[@]}")
    (( $#code )) || continue
    # The code's results are relative to it, so are moved to the positions of its characters on the command line, a
    # stretch at a time, as they're not all next to each other (e.g. with a `'\''` in it).
    _zsh_highlight_code_list $(( positions[-1] == $#BUFFER )) "$code"
    nested=()
    for i j style in $reply; do
      (( i < 0 )) && i=0
      (( j > $#code )) && j=$#code
      for (( i++; i <= j; i = k + 1 )); do
        for (( k = i; k < j && positions[k+1] == positions[k] + 1; k++ )); do :; done
        nested+=($(( positions[i] - 1 )) $positions[k] $style)
      done
    done
    # The code can have its own ff, fr and fl in.
    reply=("${nested[@]}")
    _zsh_highlight_code_expand
    triples[3*after-2,3*after-3]=("${reply[@]}")
    _zsh_highlight_code_words[$start]="$end_ $(( after - first ))"
  done
  reply=("${triples[@]}")
}

# Usage: `_zsh_highlight_code_list <has end> <code>`
#
# Run the plugin's function on the code, as on a command line of its own (as the plugin reads some things from $BUFFER
# itself), and put its results in $reply. Has end is 1 if the code runs to the end of the command line (so e.g. a path
# in it can be still being typed).
_zsh_highlight_code_list() {
  local -h BUFFER=$2
  _zsh_highlight_code_list_plain 0 '' $1 "$2"
}

# Usage: `_zsh_highlight_code_command <start> <end> <after precommand> <start:end>...`
#
# If the command at `$BUFFER[start+1,end]` is ff, fr or fl, add the word of its arguments (the `start:end` words) that's
# the code to $found (the caller's), as "start end".
_zsh_highlight_code_command() {
  emulate -L zsh
  local name
  local -a values starts ends
  local -i i
  _zsh_highlight_command_args '(ff|fr|fl)' "$@" || return
  (( $+functions[$name] )) || return
  case $name in
    (ff) i=$#values ;;  # `ff [fd args] <code>`
    (fr) i=2 ;;  # `fr <sep> <code> [files]`
    (fl) i=1 ;;  # `fl <code> [files]`
  esac
  (( i >= 1 && i <= $#values && starts[i] >= 0 )) && found+=("$starts[i] $ends[i]")
}

# Underline quoted paths too. zsh-syntax-highlighting recognises "/etc/hosts" as a path, but colours it as a string
# afterwards, which replaces the path's underline rather than adding to it. This highlighter runs straight after the
# main one and redraws any part of a path that was recoloured (e.g. a quoted string) in that colour plus underline. It
# reads the main highlighter's results from the plugin's internal (undocumented) cache variable, so a plugin upgrade
# could stop it working, in which case quoted paths just aren't underlined (a zsh upgrade could too, as zsh controls the
# "start end style" format of the cached entries). If an upgrade breaks it, go back to the zsh-syntax-highlighting and
# zsh versions in VERSIONS.md, and `brew pin zsh-syntax-highlighting`.
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
  local entry style text char code
  local -a fields stack  # stack: the positions of the brackets still open
  # For each position: whether it's in a string or comment, the style and text of the last entry covering it (the one
  # zle shows), and whether it's in a `${...}`.
  local -a quoted last last_text parameter
  local -i i code_entries  # code_entries: how many entries are left of a word of code's own (see below)
  for entry in $_zsh_highlight__highlighter_main_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    style=${fields[3]%,} text=$BUFFER[fields[1]+1,fields[2]]
    # The string that the shell code given to ff, fr or fl is in doesn't count, as the code's own entries follow.
    if (( ! code_entries )); then
      code=$_zsh_highlight_code_words[$fields[1]]
      [[ ${code%% *} == $fields[2] ]] && code_entries=${code#* }
    fi
    for (( i = fields[1] + 1; i <= fields[2]; i++ )); do
      # Strings (which share one style) and comments, including unclosed strings (styled as errors, so told apart by
      # their first character)
      if (( ! code_entries )) &&
         [[ $style == ($ZSH_HIGHLIGHT_STYLES[double-quoted-argument]|$ZSH_HIGHLIGHT_STYLES[comment]) ||
            $style == $ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed] && $text == (\'|\"|\$\')* ]]; then
        quoted[i]=1
      fi
      last[i]=$style last_text[i]=$text
    done
    (( code_entries )) && (( code_entries-- ))
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

# Colour the regexes given to the commands that take Perl-style ones, or much the same (see
# _zsh_highlight_regex_pattern): GNU grep with -P or -E, rg, fd, GNU sed with -E, and perl and my p, pp, fr and ff
# functions (in .zshrc). That's the pattern arguments of grep, rg and fd (and ff, which passes them to fd), the -F field
# separators of perl and p, and the -R record separators of p and fr. The code given to perl and p, and the scripts
# given to sed, are coloured as a whole, with their regexes among them. What a command is, and so which regexes it
# takes, is worked out as it would be run: aliases are expanded as zsh would (so my `grep` is `ggrep -P`, and `sed` is
# `gsed -E`), and a grep or sed counts only if it's GNU's (as ggrep and gsed are on macOS, and grep and sed are on
# Linux), by its --version. Then the options decide: e.g. -P or -E for grep (a mix, like `grep -E` with my alias, has
# the ones typed coloured as errors, as grep rejects it), -P for rg (else its default, Rust's regexes, as fd's), and -F
# or -g (for fd) for none. Only arguments that reach the command as typed (bar quotes and backslashes) are coloured, so
# not ones with a `$var`, `$(command)`, glob etc in. Like the highlighters above, this relies on the main highlighter's
# cache, which lists the words in order, including those of commands in `$( )` and `<( )` and in the shell code given to
# ff, fr and fl (and the rainbow highlighter's, so a regex's brackets carry on the depth of the brackets around it).
#
# If the options of p, fr or ff change, update the parsing of them below to match.
_zsh_highlight_highlighter_regex_predicate() { _zsh_highlight_highlighter_main_predicate }

_zsh_highlight_highlighter_regex_paint() {
  local -a entries=("${_zsh_highlight__highlighter_main_cache[@]}")
  _zsh_highlight_commands _zsh_highlight_regex_command
}

# Usage: `_zsh_highlight_commands <function>`
#
# Run the function for each command in $entries (the caller's, entries in the format of the main highlighter's cache,
# "start end style ..."), as `<function> <start> <end> <after precommand> <start:end>...`: the command's word is at
# `$BUFFER[start+1,end]`, it follows a precommand or not (1 or 0, as aliases aren't expanded after one, e.g.
# `sudo grep`), and its arguments are the `start:end` words. The entries list the words in order, including those of
# commands in `$( )` and `<( )`, and in the shell code given to ff, fr and fl (as noted in _zsh_highlight_code_words,
# see above), which are commands of their own.
_zsh_highlight_commands() {
  emulate -L zsh
  local callback=$1 entry text style code
  local -a fields
  # For each level of `$( )` or code the words are in: its current command, as "start end" (empty if none yet), whether
  # that follows a precommand, its arguments, as "start:end" words, whether the next word is a redirection's target
  # rather than an argument, the end of the last word, so the entries for parts of it (e.g. its quoted strings) are
  # skipped, whether it's code, and the end of the code it's in, if any (as a `$( )` in code ends with it if unclosed).
  local -a command_words=('') precommand=(0) arguments=('') redirected=(0) ends=(0) in_code=(0) limits=(0)
  local -i level=1 skip=0
  for entry in $entries; do
    (( skip )) && { (( skip-- )); continue }
    fields=(${(s: :)entry})
    while (( level > 1 && limits[level] && fields[1] >= limits[level] )); do
      _zsh_highlight_commands_end
      (( level-- ))
    done
    text=$BUFFER[fields[1]+1,fields[2]] style=${fields[3]%,}
    # The `$(` `<(` etc and `)` of a command or process substitution
    if [[ $style == $ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter] && $text == ([\$\<\>=]\(|\)) ]]; then
      if [[ $text == ')' ]]; then
        (( level > 1 && ! in_code[level] )) || continue
        _zsh_highlight_commands_end
        (( level-- ))
      else
        (( level++ ))
        command_words[level]= precommand[level]=0 arguments[level]= redirected[level]=0 ends[level]=0
        in_code[level]=0 limits[level]=$limits[level-1]
      fi
      continue
    fi
    (( fields[1] < ends[level] )) && continue
    ends[level]=$fields[2]
    if [[ $style == $ZSH_HIGHLIGHT_STYLES[command] ]]; then  # Also the style of aliases, functions, builtins etc
      [[ -n $command_words[level] ]] && _zsh_highlight_commands_end
      command_words[level]="$fields[1] $fields[2]"
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[precommand] ]]; then
      _zsh_highlight_commands_end
      precommand[level]=1
    # Redirections share their style with `;` `|` `&&` etc, so are told apart by their `<` or `>`.
    elif [[ $style == $ZSH_HIGHLIGHT_STYLES[redirection] && $text == *[\<\>]* ]]; then
      redirected[level]=1
    elif [[ $style == ($ZSH_HIGHLIGHT_STYLES[commandseparator]|$ZSH_HIGHLIGHT_STYLES[reserved-word]) ]]; then
      _zsh_highlight_commands_end
    elif (( redirected[level] )); then
      redirected[level]=0
    elif [[ -n $command_words[level] ]]; then
      arguments[level]+=" $fields[1]:$fields[2]"
      # A word of code: skip the rest of the word's own entries, and go into the code's.
      code=$_zsh_highlight_code_words[$fields[1]]
      if [[ ${code%% *} == $fields[2] ]]; then
        skip=$(( ${code#* } - 1 ))
        (( level++ ))
        command_words[level]= precommand[level]=0 arguments[level]= redirected[level]=0 ends[level]=0
        in_code[level]=1 limits[level]=$fields[2]
      fi
    fi
  done
  for (( ; level >= 1; level-- )); do _zsh_highlight_commands_end; done  # Including any unclosed `$(`
}

# Run the function given to _zsh_highlight_commands for the command at the current level (in its variables), if any,
# then clear the level for the next command.
_zsh_highlight_commands_end() {
  [[ -n $command_words[level] ]] && $callback ${=command_words[level]} $precommand[level] ${=arguments[level]}
  command_words[level]= precommand[level]=0 arguments[level]= redirected[level]=0
}

# Usage: `_zsh_highlight_command_args <pattern> <start> <end> <after precommand> <start:end>...`
#
# Put the name of the command at `$BUFFER[start+1,end]` in $name, and its arguments (the `start:end` words) in $values,
# their text (unquoted), with their start and end on the command line in $starts and $ends (-1 for those of an alias),
# all the caller's. Aliases are expanded as zsh would, again and again (but not an alias inside its own expansion, as in
# `alias rg='rg -P'`), and not after a precommand. Fail, before doing the arguments, if the name doesn't match the
# pattern.
_zsh_highlight_command_args() {
  emulate -L zsh
  local word REPLY
  local -a expansion reply
  local -A expanded
  name=$BUFFER[$2+1,$3] values=() starts=() ends=()
  if (( ! $4 )); then
    while (( $+aliases[$name] && ! $+expanded[$name] )); do
      expanded[$name]=1
      expansion=("${(@Q)${(z)aliases[$name]}}")
      name=$expansion[1]
      values=("${(@)expansion[2,-1]}" "${(@)values}")
      starts=(${expansion[2,-1]/*/-1} $starts) ends=(${expansion[2,-1]/*/-1} $ends)
    done
  fi
  name=${(Q)name}  # E.g. `\grep` (which skips the alias) is grep.
  [[ ${name:t} == ${~1} ]] || return
  for word in ${@:5}; do
    starts+=(${word%:*}) ends+=(${word#*:})
    if _zsh_highlight_regex_unquote ${word%:*} ${word#*:}; then
      values+=("$REPLY")
    else
      values+=("${(Q)BUFFER[${word%:*}+1,${word#*:}]}")
    fi
  done
}

# Usage: `_zsh_highlight_regex_command <start> <end> <after precommand> <start:end>...`
#
# Colour the regexes in the arguments (the `start:end` words) of the command at `$BUFFER[start+1,end]`, if it's one that
# takes Perl-style regexes.
_zsh_highlight_regex_command() {
  emulate -L zsh -o extended_glob
  local name value option item kind flavour=pcre REPLY
  # The arguments: their text (unquoted), and their start and end on the command line (-1 for those of an alias)
  local -a values starts ends found reply positions fields
  local -i i k
  _zsh_highlight_command_args '(grep|ggrep|rg|fd|fdfind|ff|perl|p|pp|fr|sed|gsed)' "$@" || return
  # Which program it is, by its name, but for grep and sed, by whether it's GNU's (whose regexes these follow), as
  # ggrep and gsed are on macOS (where grep and sed are BSD's), and grep and sed are on Linux. Any other grep or sed
  # isn't coloured.
  local tool=${name:t}
  case $tool in
    (grep|ggrep) _zsh_highlight_regex_is_gnu $name grep && tool=gnu-grep || return ;;
    (sed|gsed) _zsh_highlight_regex_is_gnu $name sed && tool=gnu-sed || return ;;
    (fdfind) tool=fd ;;  # fd's name on Debian and Ubuntu
  esac
  # Find the regexes, as "index offset kind": the regex is in the index'th argument, starting at its offset'th
  # character, and it's a pattern, Perl code (with regexes in), or a pattern optionally written `/like this/`.
  case $tool in
    (gnu-grep|rg)
      local short
      local -a long
      # The options that take a value, and for rg, its regex engine (pcre for PCRE2, else rust, its default) and whether
      # the regexes are fixed strings (the last of the options that set these wins). For grep, the matchers given (-P
      # -E -G -F), as "letter index", of which it rejects a mix, e.g. -E with my alias's -P.
      if [[ $tool == gnu-grep ]]; then
        short=efmdDABC
        long=(regexp file max-count directories devices before-context after-context context label binary-files include
          exclude exclude-from exclude-dir group-separator)
      else
        short=efEmjgdtTABCMr
        long=(regexp file encoding max-count threads glob max-depth type type-not after-context before-context context
          max-columns replace pre pre-glob dfa-size-limit engine regex-size-limit iglob ignore-file max-filesize
          type-add type-clear color colors context-separator field-context-separator field-match-separator hostname-bin
          hyperlink-format path-separator sort sortr generate)
      fi
      local engine=rust
      local -i fixed=0 given=0 ended=0  # given: whether patterns were given by -e or -f, not positionally
      local -a positional matchers
      for (( i = 1; i <= $#values; i++ )); do
        value=$values[i]
        if (( ended )) || [[ $value != -?* ]]; then
          positional+=($i)
        elif [[ $value == -- ]]; then
          ended=1
        elif [[ $value == --* ]]; then
          option=${${value#--}%%=*}
          if [[ $tool == gnu-grep ]]; then
            case $option in
              (perl-regexp) matchers+=("P $i") ;;
              (extended-regexp) matchers+=("E $i") ;;
              (basic-regexp) matchers+=("G $i") ;;
              (fixed-strings) matchers+=("F $i") ;;
            esac
          fi
          if [[ $value == *=* ]]; then
            item="$i $(( $#option + 4 ))" value=${value#*=}
          elif (( $long[(Ie)$option] )); then
            (( i++ ))
            item="$i 1" value=$values[i]
          fi
          case $option in
            (regexp) found+=("$item pattern"); given=1 ;;
            (file) given=1 ;;
            (pcre2|auto-hybrid-regex) engine=pcre ;;
            (no-pcre2|no-auto-hybrid-regex) engine=rust ;;
            (engine) [[ $value == default ]] && engine=rust || engine=pcre ;;  # auto uses PCRE2 for what needs it.
            (fixed-strings) fixed=1 ;;
            (no-fixed-strings) fixed=0 ;;
          esac
        else  # A bundle of short options, e.g. `-iA3`
          for (( k = 2; k <= $#value; k++ )); do
            if [[ $tool == gnu-grep ]]; then
              [[ $value[k] == [PEGF] ]] && matchers+=("$value[k] $i")
            else
              [[ $value[k] == P ]] && engine=pcre
              [[ $value[k] == F ]] && fixed=1
            fi
            [[ $short == *"$value[k]"* ]] || continue
            # The option's value is the rest of the bundle, or else the next argument.
            if (( k < $#value )); then item="$i $(( k + 1 ))"; else (( i++ )); item="$i 1"; fi
            [[ $value[k] == e ]] && found+=("$item pattern")
            [[ $value[k] == [ef] ]] && given=1
            break
          done
        fi
      done
      (( ! given && $#positional )) && found+=("$positional[1] 1 pattern")
      if [[ $tool == gnu-grep ]]; then
        local -a letters=(${(u)matchers%% *})
        if (( $#letters > 1 )); then  # Colour the typed matchers (not those from an alias) as errors.
          for item in $matchers; do
            i=${item#* }
            (( starts[i] >= 0 )) && _zsh_highlight_add_highlight $starts[i] $ends[i] syntax-error
          done
          found=()
        elif [[ $letters == P ]]; then
          flavour=pcre
        elif [[ $letters == E ]]; then
          flavour=ere
        else  # Basic regexes (the default) or fixed strings
          found=()
        fi
      else
        (( fixed )) && found=() || flavour=$engine
      fi ;;
    (perl)
      # The code comes from -e (or -E) options, without which the first argument is a script's file. The switches that
      # take a value use the rest of their bundle (or the next argument, for -e), as in p below.
      for (( i = 1; i <= $#values; i++ )); do
        value=$values[i]
        [[ $value == -?* ]] || break
        [[ $value == -- ]] && break
        for (( k = 2; k <= $#value; k++ )); do
          case $value[k] in
            ([eE])
              if (( k < $#value )); then found+=("$i $(( k + 1 )) code"); else (( i++ )); found+=("$i 1 code"); fi
              break ;;
            (F) found+=("$i $(( k + 1 )) slashed"); break ;;
            (0) if [[ $value[k+1] == x ]]; then (( k++ )); while [[ $value[k+1] == [[:xdigit:]] ]]; do (( k++ )); done
                else while [[ $value[k+1] == [0-7] ]]; do (( k++ )); done; fi ;;
            (l) while [[ $value[k+1] == [0-7] ]]; do (( k++ )); done ;;
            ([acnpsStTuUvwWX]) ;;
            (*) break ;;  # Like -i, -M and -I, the rest of the switches take the rest of the bundle.
          esac
        done
      done ;;
    (p|pp)
      (( $+functions[$name] )) || return
      # As p parses them: switches, then the code. A switch that takes a value (like -R, -F, -i or -M) uses the rest of
      # its bundle.
      for (( i = 1; i <= $#values; i++ )); do
        value=$values[i]
        [[ $value == -* ]] || break
        [[ $value == -- ]] && { (( i++ )); break }
        for (( k = 2; k <= $#value; k++ )); do
          case $value[k] in
            ([RF]) found+=("$i $(( k + 1 )) slashed"); break ;;
            (0) if [[ $value[k+1] == x ]]; then (( k++ )); while [[ $value[k+1] == [[:xdigit:]] ]]; do (( k++ )); done
                else while [[ $value[k+1] == [0-7] ]]; do (( k++ )); done; fi ;;
            (l) while [[ $value[k+1] == [0-7] ]]; do (( k++ )); done ;;
            ([anpscSTtUuWwX]) ;;
            (*) break ;;
          esac
        done
      done
      found+=("$i 1 code") ;;
    (fr) (( $+functions[$name] )) && found=("1 1 slashed") ;;  # `fr <separator> <code>` (the code is the shell's)
    (fd|ff)
      # ff passes all its arguments but the last (the code to run for each file) to fd.
      local -i last=$#values glob=0 fixed=0 ended=0
      if [[ $name == ff ]]; then
        (( $+functions[$name] )) || return
        (( last-- ))
      fi
      local short=dEtecSojC
      local -a positional long=(and max-depth min-depth exact-depth exclude type extension size changed-within
        changed-before newer older change-newer-than change-older-than owner format batch-size ignore-file color
        ignore-contain threads max-results base-directory path-separator search-path)
      for (( i = 1; i <= last; i++ )); do
        value=$values[i]
        if (( ended )) || [[ $value != -?* ]]; then
          positional+=($i)
        elif [[ $value == -- ]]; then
          ended=1
        elif [[ $value == --* ]]; then
          option=${${value#--}%%=*}
          if [[ $value == *=* ]]; then
            item="$i $(( $#option + 4 ))"
          elif (( $long[(Ie)$option] )); then
            (( i++ ))
            item="$i 1"
          fi
          case $option in
            (and) found+=("$item pattern") ;;  # Another pattern, which files must match too
            (glob) glob=1 ;;
            (regex) glob=0 ;;
            (fixed-strings) fixed=1 ;;
            (exec|exec-batch) _zsh_highlight_regex_skip_command ;;
          esac
        else  # A bundle of short options, e.g. `-HId2`
          for (( k = 2; k <= $#value; k++ )); do
            case $value[k] in
              (g) glob=1 ;;
              (F) fixed=1 ;;
              ([xX]) _zsh_highlight_regex_skip_command; break ;;
            esac
            [[ $short == *"$value[k]"* ]] || continue
            (( k < $#value )) || (( i++ ))  # The option's value is the rest of the bundle, or else the next argument.
            break
          done
        fi
      done
      (( $#positional )) && found+=("$positional[1] 1 pattern")  # The second is the directory to search.
      (( glob || fixed )) && found=()
      flavour=rust ;;
    (gnu-sed)
      # The script comes from -e options, without which it's the first argument. Only extended regexes (-E or -r, which
      # my alias for sed adds) are coloured, as the basic ones' differ (e.g. `\(` is a group, `(` a bracket).
      local -i extended=0 given=0 ended=0
      local -a positional long=(expression file line-length)
      for (( i = 1; i <= $#values; i++ )); do
        value=$values[i]
        if (( ended )) || [[ $value != -?* ]]; then
          positional+=($i)
        elif [[ $value == -- ]]; then
          ended=1
        elif [[ $value == --* ]]; then
          option=${${value#--}%%=*}
          if [[ $value == *=* ]]; then
            item="$i $(( $#option + 4 ))"
          elif (( $long[(Ie)$option] )); then
            (( i++ ))
            item="$i 1"
          fi
          case $option in
            (expression) found+=("$item sed"); given=1 ;;
            (file) given=1 ;;
            (regexp-extended) extended=1 ;;
          esac
        else  # A bundle of short options, e.g. `-nE`
          for (( k = 2; k <= $#value; k++ )); do
            case $value[k] in
              ([Er]) extended=1 ;;
              (i) break ;;  # -i takes the rest of the bundle as its backup suffix.
              ([efl])
                if (( k < $#value )); then item="$i $(( k + 1 ))"; else (( i++ )); item="$i 1"; fi
                [[ $value[k] == e ]] && found+=("$item sed")
                [[ $value[k] == [ef] ]] && given=1
                break ;;
            esac
          done
        fi
      done
      (( ! given && $#positional )) && found+=("$positional[1] 1 sed")
      (( extended )) || found=() ;;
  esac
  for item in $found; do
    fields=(${=item})
    i=$fields[1] k=$fields[2] kind=$fields[3]
    (( i <= $#values && starts[i] >= 0 )) || continue
    _zsh_highlight_regex_unquote $starts[i] $ends[i] || continue
    value=${REPLY[k,-1]} positions=("${(@)reply[k,-1]}")
    (( $#value )) || continue
    _zsh_highlight_regex_depth $positions[1]
    case $kind in
      (pattern) _zsh_highlight_regex_pattern $flavour $REPLY "$value" $positions ;;
      (code) _zsh_highlight_regex_code $REPLY "$value" $positions ;;
      (sed) _zsh_highlight_regex_sed $REPLY "$value" $positions ;;
      (slashed)
        if [[ $value == /?*/ ]]; then
          _zsh_highlight_add_highlight $(( positions[1] - 1 )) $positions[1] perl-delimiter
          _zsh_highlight_add_highlight $(( positions[-1] - 1 )) $positions[-1] perl-delimiter
          value=$value[2,-2] positions=("${(@)positions[2,-2]}")
        fi
        _zsh_highlight_regex_pattern pcre $REPLY "$value" $positions ;;
    esac
  done
}

# Skip the command that fd's -x or -X runs, up to the `;` that ends it (or the end), in the arguments of
# _zsh_highlight_regex_command (in its variables).
_zsh_highlight_regex_skip_command() {
  while (( i < last )) && [[ $values[i+1] != ';' ]]; do (( i++ )); done
  (( i++ ))
}

# Succeed if the command $1 (a name, or a path) is GNU's $2 (e.g. GNU grep, as ggrep is on macOS and grep is on Linux),
# going by its --version. That's run once per command (and the results passed to my ctrl+r's highlighting, see
# .zshrc), and only for the one found in $PATH (so for a path, only if it's to that same file), so that typing the path
# to some other program called e.g. grep never runs it.
typeset -gA _zsh_highlight_regex_gnu  # Command's file -> 0 if it's GNU's, else 1
_zsh_highlight_regex_is_gnu() {
  emulate -L zsh
  local file=$commands[${1:t}]
  [[ -n $file ]] || return 1
  [[ $1 != */* || ${1:A} == ${file:A} ]] || return 1
  if (( ! $+_zsh_highlight_regex_gnu[$file] )); then
    # E.g. "grep (GNU grep) 3.12", whereas macOS's says "grep (BSD grep, GNU compatible) 2.6.0-FreeBSD".
    [[ ${${(f)"$($file --version 2>/dev/null </dev/null)"}[1]} == *"(GNU $2)"* ]]
    _zsh_highlight_regex_gnu[$file]=$?
  fi
  (( _zsh_highlight_regex_gnu[$file] == 0 ))
}

# Put the text that the word at `$BUFFER[$1+1,$2]` passes to its command (i.e. without its quotes and backslashes) in
# $REPLY, and the position on the command line of each of its characters in $reply. Fail if it's not passed as is (e.g.
# it has a `$var`, `$'...'` or glob), as then the positions don't match up. An unclosed quote (e.g. while still typing)
# counts as closed at the end of the word.
_zsh_highlight_regex_unquote() {
  emulate -L zsh
  local quote= char
  local -i i
  REPLY= reply=()
  for (( i = $1 + 1; i <= $2; i++ )); do
    char=$BUFFER[i]
    if [[ $quote == "'" ]]; then
      [[ $char == "'" ]] && { quote=; continue }
    elif [[ $quote == '"' ]]; then
      case $char in
        ('"') quote=; continue ;;
        ('\') [[ $BUFFER[i+1] == [\$\`\"\\] ]] && (( i++ )) ;;  # Otherwise the `\` is kept.
        ([\$\`!]) return 1 ;;
      esac
    else
      case $char in
        ([\'\"]) quote=$char; continue ;;
        ('\') (( ++i <= $2 )) || break ;;
        ([[:alnum:]_.,:/+%@-]) ;;
        ('=') (( i > $1 + 1 )) || return 1 ;;  # At the start, it's an `=command` expansion.
        ('^') [[ $zsyh_user_options[extendedglob] == off ]] || return 1 ;;
        (*) return 1 ;;
      esac
    fi
    REPLY+=$BUFFER[i] reply+=($i)
  done
  return 0
}

# Put in $REPLY how many of the brackets that the rainbow highlighter coloured are open at position $1 of the command
# line.
_zsh_highlight_regex_depth() {
  emulate -L zsh
  local entry
  local -a fields
  REPLY=0
  for entry in $_zsh_highlight__highlighter_rainbow_cache; do  # Entries are "start end style ...".
    fields=(${(s: :)entry})
    (( fields[2] < $1 )) || continue
    case $BUFFER[fields[2]] in
      ([\(\[\{]) (( REPLY++ )) ;;
      ([\)\]\}]) [[ ${fields[3]%,} == $ZSH_HIGHLIGHT_STYLES[bracket-unexpected] ]] || (( REPLY-- )) ;;
    esac
  done
}

# Usage: `_zsh_highlight_regex_pattern <flavour> <depth> <regex> <position>...`
#
# Colour a Perl-style regex, whose characters are at the given positions on the command line. Its brackets carry on from
# the depth given. The flavour is pcre (PCRE2's, as in grep and rg), perl (the same, but in Perl code, so a `$` or `@`
# followed by a name is a variable), rust (Rust's regex crate's, as in fd), which lacks lookarounds, backreferences and
# some escapes and groups (coloured as errors), but has classes in classes, e.g. `[a-z&&[^aeiou]]`, ere (GNU's extended
# regexes, as in grep -E), which only has the escapes `\w` `\W` `\s` `\S` `\b` `\B` `\<` `\>` and `\1` etc (others, like
# `\d`, match the letter instead, with a warning), no `(?...)` groups or lazy quantifiers (`a*?` is `(a*)?`), and in a
# `[...]`, a `\` is literal, or sed (the same, as in sed -E, but with sed's own escapes too, e.g. `\n` `\t` `\x41`,
# which also work in a `[...]`, while other escapes silently match the letter).
_zsh_highlight_regex_pattern() {
  emulate -L zsh -o extended_glob
  local s=$3 close style
  local -a pos=("${@:4}") groups match mbegin mend  # groups: the positions of the `(`s still open
  # class: how many `[`s are open (only ever 1 but in rust), and first: where the innermost one's contents start
  local -i depth=$2 i j n=$#3 class=0 first quoted=0 rust=0 gnu=0 sed=0 interpolate=0
  [[ $1 == rust ]] && rust=1
  [[ $1 == (ere|sed) ]] && gnu=1
  [[ $1 == sed ]] && sed=1
  [[ $1 == perl ]] && interpolate=1
  for (( i = 1; i <= n; i = j + 1 )); do
    j=i
    if (( quoted )); then  # In `\Q...\E`, where everything is literal
      [[ $s[i,i+1] == '\E' ]] && { quoted=0 j=i+1; _zsh_highlight_regex_add $i $j regex-escape }
      continue
    fi
    if [[ $s[i] == '\' ]]; then  # An escape: `\[` `\d` `\x41` `\x{263A}` `\p{L}` `\k<name>` `\g-1` `\12` etc
      if (( gnu && class )) &&
         { (( ! sed )) || [[ $s[i+1] != [ntfvarc] && $s[i+1,i+2] != (d[0-9]|o[0-7]|x[[:xdigit:]]) ]] }; then
        continue  # A literal `\`
      fi
      (( j++ ))
      case $s[j] in
        ([xopPNgkb])
          if [[ $s[j+1] == '{' && ( $s[j] != b || rust -eq 1 ) ]]; then  # Including rust's `\b{start}` etc
            (( j += 2 )); while (( j < n )) && [[ $s[j] != '}' ]]; do (( j++ )); done
          elif [[ $s[j] == [gk] && $s[j+1] == [\<\'] ]]; then
            close=${s[j+1]/\</>}
            (( j += 2 )); while (( j < n )) && [[ $s[j] != "$close" ]]; do (( j++ )); done
          elif [[ $s[j] == x ]]; then
            while (( j < i + 3 )) && [[ $s[j+1] == [[:xdigit:]] ]]; do (( j++ )); done
          elif [[ $s[j] == g ]]; then
            [[ $s[j+1] == - ]] && (( j++ )); while [[ $s[j+1] == [0-9] ]]; do (( j++ )); done
          elif [[ $s[j] == [pP] ]]; then
            (( j++ ))
          elif (( sed )) && [[ $s[j] == o ]]; then  # sed's `\o101`
            while (( j < i + 4 )) && [[ $s[j+1] == [0-7] ]]; do (( j++ )); done
          fi ;;
        (d) (( sed )) && while (( j < i + 4 )) && [[ $s[j+1] == [0-9] ]]; do (( j++ )); done ;;  # sed's `\d097`
        (c) (( j++ )) ;;
        ([0-9]) while [[ $s[j+1] == [0-9] ]]; do (( j++ )); done ;;
        (Q) (( rust || gnu )) || quoted=1 ;;
      esac
      (( j > n )) && j=n
      style=regex-escape
      # Only these letters (and digits) can be escaped, while any other character can (e.g. `\(` is just `(`). PCRE's
      # `\l` `\L` `\u` `\U` `\F` are errors, but in Perl, they're string escapes that change the case of what follows.
      if (( rust )); then
        [[ $s[i+1] == [[:alnum:]] && $s[i+1] != [dDwWsSbBAzxpPtnrfva] ]] && style=syntax-error
      elif (( sed )); then
        [[ $s[i+1] == [[:alnum:]] ]] && ! [[ $s[i+1] == [wWsSbBntfvarc1-9] ]] &&
          ! { [[ $s[i+1] == [dox] ]] && (( j > i + 1 )) } && style=syntax-error
      elif (( gnu )); then
        [[ $s[i+1] == [[:alnum:]] && $s[i+1] != [wWsSbB1-9] ]] && style=syntax-error
      else
        [[ $s[i+1] == [iIjJmMOqTyY] || $s[i+1] == o && $s[i+2] != '{' ]] && style=syntax-error
        (( ! interpolate )) && [[ $s[i+1] == [lLuUF] ]] && style=syntax-error
      fi
      _zsh_highlight_regex_add $i $j $style
    elif (( class )); then  # In a `[...]`
      if [[ $s[i] == ']' ]] && (( i > first )); then  # A `]` first in the class is literal.
        _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#groups + class - 1) % 6 + 1 ))
        (( class-- ))
      elif [[ $s[i,-1] == (#b)(\[:\^#[[:alpha:]]##:\])* ]]; then  # E.g. `[:alpha:]`
        (( j += $#match[1] - 1 ))
        _zsh_highlight_regex_add $i $j regex-escape
      elif (( rust )) && [[ $s[i] == '[' ]]; then  # A class in the class
        _zsh_highlight_regex_class
      elif (( rust )) && [[ $s[i,i+1] == ('&&'|'--'|'~~') ]]; then  # Intersection, difference, symmetric difference
        (( j++ ))
        _zsh_highlight_regex_add $i $j regex-operator
      elif [[ $s[i] == - ]] && (( i > first )) && [[ $s[i+1] != ']' ]]; then  # A range
        _zsh_highlight_regex_add $i $i regex-operator
      fi
    else
      case $s[i] in
        ('[') _zsh_highlight_regex_class ;;
        ('(')
          if [[ $s[i,i+2] == '(?#' ]]; then  # A comment, up to the next `)`
            while (( j < n )) && [[ $s[j] != ')' ]]; do (( j++ )); done
            (( rust || gnu )) && style=syntax-error || style=comment
            _zsh_highlight_regex_add $i $j $style
            continue
          fi
          groups+=($i)
          _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#groups - 1) % 6 + 1 ))
          # What kind of group it is: `?:` `?=` `?!` `?>` `?|` `?<=` `?<!` `?<name>` `?'name'` `?P<name>`, flags like
          # `?i` or `?i-x:`, a recursion like `?R` `?1` `?&name` `?P>name` (all up to the `)`), or a verb like `*SKIP`
          if [[ $s[i+1] == '?' ]]; then
            j=i+1
            case $s[i+2] in
              ([:=!\>\|]) j=i+2 ;;
              ('<') if [[ $s[i+3] == [=!] ]]; then j=i+3
                    else while (( j < n )) && [[ $s[j] != '>' ]]; do (( j++ )); done; fi ;;
              ("'") (( j++ )); while (( j < n )) && [[ $s[j+1] != "'" ]]; do (( j++ )); done; (( j++ )) ;;
              (P) if [[ $s[i+3] == '<' ]]; then while (( j < n )) && [[ $s[j] != '>' ]]; do (( j++ )); done
                  else while (( j < n )) && [[ $s[j+1] != ')' ]]; do (( j++ )); done; fi ;;
              (*) while [[ $s[j+1] == [[:alnum:]_^\&+-] ]]; do (( j++ )); done; [[ $s[j+1] == : ]] && (( j++ )) ;;
            esac
            style=regex-group
            # Rust only has these: `?:` `?<name>` `?P<name>` and flags (`R` being one, not a recursion).
            (( rust )) && [[ $s[i+1,j] != ('?:'|'?<'[^=!]*|'?P<'*|'?'[imsxRU-]##(|:)) ]] && style=syntax-error
            (( gnu )) && style=syntax-error  # GNU's have none.
            _zsh_highlight_regex_add $(( i + 1 )) $j $style
          elif [[ $s[i+1] == '*' && $s[i+2] == [[:upper:]] ]]; then
            (( j++ )); while (( j < n )) && [[ $s[j+1] != ')' ]]; do (( j++ )); done
            (( rust || gnu )) && style=syntax-error || style=regex-group
            _zsh_highlight_regex_add $(( i + 1 )) $j $style
          fi ;;
        (')')
          if (( $#groups )); then
            _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#groups - 1) % 6 + 1 ))
            groups[-1]=()
          else
            _zsh_highlight_regex_add $i $i bracket-unexpected
          fi ;;
        ([\$@])
          if (( interpolate )) && [[ $s[i+1] == [[:alnum:]_:{] ]] && [[ $s[i] == '$' || $s[i+1] != [0-9] ]]; then
            if [[ $s[i+1] == '{' ]]; then
              while (( j < n )) && [[ $s[j] != '}' ]]; do (( j++ )); done
            else
              while [[ $s[j+1] == [[:alnum:]_:] ]]; do (( j++ )); done
            fi
            _zsh_highlight_regex_add $i $j perl-variable
          elif [[ $s[i] == '$' ]]; then
            _zsh_highlight_regex_add $i $i regex-operator
          fi ;;
        ([\|^]) _zsh_highlight_regex_add $i $i regex-operator ;;
        (.) _zsh_highlight_regex_add $i $i regex-escape ;;
        ([*+?{])  # A quantifier (as is a `{` before e.g. `2}` `2,}` `2,3}` `,3}`), lazy or possessive or not
          style=regex-operator
          if [[ $s[i] == '{' ]]; then
            [[ $s[i,-1] == (#b)(\{[0-9]#(,[0-9]#|)\})* && $match[1] == *[0-9]* ]] || continue
            (( j += $#match[1] - 1 ))
            (( rust )) && [[ $match[1] == '{,'* ]] && style=syntax-error  # Rust needs the minimum.
          fi
          _zsh_highlight_regex_add $i $j $style
          if [[ $s[j+1] == [?+] ]]; then  # Lazy or possessive, which GNU's don't have
            (( j++ ))
            (( gnu )) && style=syntax-error
            _zsh_highlight_regex_add $j $j $style
          fi ;;
      esac
    fi
  done
}

# Colour the `[` at `$s[i]` that starts a class, and its `^` if it has one, for _zsh_highlight_regex_pattern (in its
# variables).
_zsh_highlight_regex_class() {
  (( class++ ))
  _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#groups + class - 1) % 6 + 1 ))
  first=i+1
  [[ $s[i+1] == '^' ]] && { _zsh_highlight_regex_add $first $first regex-operator; (( first++, j++ )) }
}

# Usage: `_zsh_highlight_regex_code <depth> <code> <position>...`
#
# Colour some Perl code, whose characters are at the given positions on the command line: its keywords, functions,
# variables, strings, numbers, operators, comments and brackets (carrying on from the depth given), and its regexes, in
# `/.../` (where a value is expected, else it's a division), `m/.../`, `s/.../.../` and `qr/.../` (with any delimiters).
# It's a simple tokenizer rather than a parser (only perl can parse Perl), so e.g. heredocs and POD aren't recognised,
# which one-liners rarely have.
_zsh_highlight_regex_code() {
  emulate -L zsh -o extended_glob
  local s=$2 word previous style  # previous: the last token, if it was a word
  local -a pos=("${@:3}") brackets  # brackets: the brackets still open
  local -i depth=$1 i j k n=$#2 regex=1 parts quoted interpolate  # regex: whether a `/` here would start a regex
  # Colour the code as text, rather than as the shell string it's in, a stretch at a time (as e.g. a `'\''` in it keeps
  # the shell's colours).
  for (( i = 1; i <= n; i = j + 1 )); do
    for (( j = i; j < n && pos[j+1] == pos[j] + 1; j++ )); do :; done
    _zsh_highlight_regex_add $i $j perl-default
  done
  for (( i = 1; i <= n; i++ )); do
    [[ $s[i] == [[:space:]] ]] && continue
    word=
    case $s[i] in
      ('#')
        for (( j = i; j < n; j++ )); do [[ $s[j+1] == $'\n' ]] && break; done
        _zsh_highlight_regex_add $i $j perl-comment
        i=j ;;
      ([\'\"\`])
        for (( j = i + 1; j <= n; j++ )); do
          [[ $s[j] == '\' ]] && { (( j++ )); continue }
          [[ $s[j] == "$s[i]" ]] && break
        done
        _zsh_highlight_regex_add $i $(( j > n ? n : j )) perl-string
        [[ $s[i] == "'" ]] && interpolate=0 || interpolate=1
        _zsh_highlight_regex_string $(( i + 1 )) $(( j - 1 )) $interpolate "$s[i]"
        i=j regex=0 ;;
      ([\$@%])  # A variable, e.g. `$x` `@x` `%x` `$#x` `${x}` `$1` `$/`, or else `%` as modulus
        if [[ $s[i] == % ]] && { (( ! regex )) || [[ $s[i+1] != [[:alpha:]_{^] ]] }; then
          _zsh_highlight_regex_add $i $i perl-operator
          regex=1
          continue
        fi
        j=i
        [[ $s[j,j+1] == '$#' ]] && (( j++ ))
        case $s[j+1] in
          ('{') while (( j < n )) && [[ $s[j] != '}' ]]; do (( j++ )); done ;;
          ([[:alpha:]_:]) while [[ $s[j+1] == [[:alnum:]_:] ]]; do (( j++ )); done ;;
          ([0-9]) while [[ $s[j+1] == [0-9] ]]; do (( j++ )); done ;;
          ('^') (( j += 2 )) ;;
          ([^[:space:]]) [[ $s[i] == '$' ]] && (( j++ )) ;;
        esac
        (( j > n )) && j=n
        _zsh_highlight_regex_add $i $j perl-variable
        i=j regex=0 ;;
      ([0-9])  # E.g. `42` `1.5` `1_000` `0x1f` `1e3`, but not the `..` of `1..9`
        for (( j = i; j < n; j++ )); do
          [[ $s[j+1] == [[:alnum:]_] || $s[j+1] == . && $s[j+2] == [0-9] ]] || break
        done
        _zsh_highlight_regex_add $i $j perl-number
        i=j regex=0 ;;
      ([[:alpha:]_])  # A word, including a module's, e.g. `List::Util`
        j=i
        while [[ $s[j+1] == [[:alnum:]_] || $s[j+1,j+2] == '::' ]]; do
          [[ $s[j+1] == : ]] && (( j += 2 )) || (( j++ ))
        done
        word=$s[i,j]
        # A quote-like operator, unless it's a method (`->s`) or a hash key (`{s}` or `s => 1`). Its delimiter follows
        # straight after, or after spaces if it's a bracket.
        k=j+1 quoted=0
        while [[ $s[k] == [[:space:]] ]]; do (( k++ )); done
        if [[ $word == (m|qr|s|tr|y|q|qq|qw|qx) && $s[i-2,i-1] != '->' ]]; then
          [[ $s[k] == [\(\[\{\<] ]] && quoted=1
          (( k == j + 1 )) && [[ $s[k] == [^[:alnum:][:space:]_=\;\)\]\}\>] ]] && quoted=1
        fi
        if (( quoted )); then
          _zsh_highlight_regex_add $i $j perl-quote-operator
          parts=1
          [[ $word == (s|tr|y) ]] && parts=2
          _zsh_highlight_regex_quoted $k $word $parts
          i=$REPLY regex=0 word=
          continue
        fi
        style=
        if [[ $s[k,k+1] == '=>' || $s[i-1] == '{' && $s[k] == '}' ]]; then
          :  # A hash key
        elif [[ $previous == (use|no|require|package) ]]; then
          style=perl-module
        elif [[ $previous == sub || $s[i-2,i-1] == '->' ]]; then  # A sub's name, or a method
          style=perl-function
        elif (( $_zsh_highlight_perl_keywords[(Ie)$word] )); then
          style=perl-keyword
        elif (( $_zsh_highlight_perl_word_operators[(Ie)$word] )); then
          style=perl-operator
        elif (( $_zsh_highlight_perl_functions[(Ie)$word] )) || [[ $s[k] == '(' ]]; then
          style=perl-function
        elif [[ $word == *::* ]]; then
          style=perl-module
        fi
        [[ -n $style ]] && _zsh_highlight_regex_add $i $j $style
        # After a keyword, an operator or some functions, a value is expected, so e.g. a `/` starts a regex and a `%`
        # starts a hash.
        [[ $style == (perl-keyword|perl-operator) ]] || (( $_zsh_highlight_perl_before_value[(Ie)$word] )) &&
          regex=1 || regex=0
        i=j ;;
      ('/')
        if (( regex )); then
          _zsh_highlight_regex_quoted $i m 1
          i=$REPLY regex=0
        else  # A division, or `//` (defined-or) or `/=`
          j=i
          [[ $s[j+1] == / ]] && (( j++ ))
          [[ $s[j+1] == = ]] && (( j++ ))
          _zsh_highlight_regex_add $i $j perl-operator
          i=j regex=1
        fi ;;
      ([\(\[\{])
        brackets+=($s[i])
        _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#brackets - 1) % 6 + 1 ))
        regex=1 ;;
      ([\)\]\}])
        if (( $#brackets )) && [[ $brackets[-1]$s[i] == ('()'|'[]'|'{}') ]]; then
          _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#brackets - 1) % 6 + 1 ))
          brackets[-1]=()
        else
          _zsh_highlight_regex_add $i $i bracket-unexpected
        fi
        regex=0 ;;
      ([\;,]) _zsh_highlight_regex_add $i $i perl-punctuation; regex=1 ;;
      (*) _zsh_highlight_regex_add $i $i perl-operator; regex=1 ;;
    esac
    previous=$word
  done
}

typeset -ga _zsh_highlight_perl_keywords=(my our local state if elsif else unless while until for foreach do last next
  redo goto return sub package use no require BEGIN END)
typeset -ga _zsh_highlight_perl_word_operators=(and or not xor eq ne lt gt le ge cmp x isa)
typeset -ga _zsh_highlight_perl_functions=(print printf say split join push pop shift unshift splice grep map sort
  reverse keys values each delete exists defined undef length substr index rindex sprintf lc uc lcfirst ucfirst fc chomp
  chop chr ord abs int sqrt sin cos atan2 exp log hex oct rand srand exit die warn eval open close binmode eof readline
  time localtime gmtime sleep system exec wantarray ref bless scalar wait waitpid unlink rename mkdir rmdir chdir
  opendir readdir closedir stat lstat pack unpack quotemeta glob select seek tell read sysread syswrite getc fileno
  utime chmod chown kill fork pipe caller lock)
# The functions after which a value is expected (as after the keywords and word operators above)
typeset -ga _zsh_highlight_perl_before_value=(split grep map join print say push unshift die warn)

# Usage: `_zsh_highlight_regex_quoted <start> <operator> <parts>`
#
# Colour a quote-like operator (`m` `qr` `s` `q` `tr` and the like, or a `/.../`) in the code of
# _zsh_highlight_regex_code (in its variables): its delimiters (the first at start), its contents, which are 1 or 2
# parts (e.g. the pattern and the replacement of `s`), and its flags. Put the position of its last character in $REPLY.
_zsh_highlight_regex_quoted() {
  emulate -L zsh -o extended_glob
  local open close kind flavour
  local -i k=$1 j part nesting flags
  for (( part = 1; part <= $3; part++ )); do
    # The second part has its own delimiters if the first's were brackets (e.g. `s{...}{...}`, with spaces allowed
    # between), else shares the first's closing one (e.g. `s/.../.../`).
    if (( part == 2 )); then
      (( j > n )) && break  # The first part is unclosed.
      if [[ $open == "$close" ]]; then
        k=j
      else
        for (( k = j + 1; k < n; k++ )); do [[ $s[k] == [[:space:]] ]] || break; done
      fi
    fi
    open=$s[k] close=$s[k]
    case $open in
      ('(') close=')' ;;
      ('[') close=']' ;;
      ('{') close='}' ;;
      ('<') close='>' ;;
    esac
    nesting=0
    for (( j = k + 1; j <= n; j++ )); do
      if [[ $s[j] == '\' ]]; then
        (( j++ ))
      elif [[ $s[j] == "$close" ]]; then
        (( nesting-- == 0 )) && break
      elif [[ $s[j] == "$open" ]]; then
        (( nesting++ ))
      fi
    done
    # What the part is: a regex (the first of `m`, `qr` and `s`), a string that variables are interpolated into (`qq`,
    # `qx` and the second of `s`), or a plain string. A `'` delimiter stops variables being interpolated, as in a
    # string.
    case $2 in
      (m|qr) kind=regex ;;
      (s) (( part == 1 )) && kind=regex || kind=interpolated ;;
      (qq|qx) kind=interpolated ;;
      (*) kind=plain ;;
    esac
    [[ $open == "'" ]] && interpolate=0 || interpolate=1
    [[ $kind == interpolated ]] && (( ! interpolate )) && kind=plain
    (( j > k + 1 )) && _zsh_highlight_regex_add $(( k + 1 )) $(( j - 1 )) perl-string
    case $kind in
      (regex)
        (( interpolate )) && flavour=perl || flavour=pcre
        _zsh_highlight_regex_pattern $flavour $(( depth + $#brackets )) "$s[k+1,j-1]" "${(@)pos[k+1,j-1]}" ;;
      (interpolated) _zsh_highlight_regex_string $(( k + 1 )) $(( j - 1 )) 1 "$close" ;;
      (plain) _zsh_highlight_regex_string $(( k + 1 )) $(( j - 1 )) 0 "$close" ;;
    esac
    [[ $part == 1 || $open != "$close" ]] && _zsh_highlight_regex_add $k $k perl-delimiter
    (( j <= n )) && _zsh_highlight_regex_add $j $j perl-delimiter
  done
  (( j > n )) && j=n
  flags=j+1
  while [[ $s[j+1] == [[:alpha:]] ]]; do (( j++ )); done  # E.g. `g` `i` `x`
  (( j >= flags )) && _zsh_highlight_regex_add $flags $j perl-quote-operator
  REPLY=$j
}

# Usage: `_zsh_highlight_regex_string <start> <end> <interpolate> <delimiter>`
#
# Colour the escapes in `$s[start,end]`, a string in the code of _zsh_highlight_regex_code (in its variables) that ends
# with the delimiter given, and if interpolate is 1, the variables interpolated into it. Without interpolation, the only
# escapes are `\\` and the delimiter's.
_zsh_highlight_regex_string() {
  emulate -L zsh
  local -i k j
  for (( k = $1; k <= $2; k = j + 1 )); do
    j=k
    if [[ $s[k] == '\' ]]; then  # E.g. `\n` `\"` `\x41` `\x{263A}` `\N{U+263A}` `\cA` `\012`
      if (( $3 )); then
        (( j++ ))
        case $s[j] in
          ([xNo])
            if [[ $s[j+1] == '{' ]]; then
              while (( j < $2 )) && [[ $s[j] != '}' ]]; do (( j++ )); done
            elif [[ $s[j] == x ]]; then
              while (( j < k + 3 )) && [[ $s[j+1] == [[:xdigit:]] ]]; do (( j++ )); done
            fi ;;
          (c) (( j++ )) ;;
          ([0-7]) while (( j < k + 3 )) && [[ $s[j+1] == [0-7] ]]; do (( j++ )); done ;;
        esac
      elif [[ $s[k+1] == '\' || $s[k+1] == "$4" ]]; then
        (( j++ ))
      else
        continue
      fi
      style=perl-escape
      # Perl warns of an escape of any other letter (but any other character can be escaped, e.g. `\(` is just `(`).
      (( $3 )) && [[ $s[k+1] == [[:alpha:]] && $s[k+1] != [tnrfbaexNocluLUFQE] ]] && style=syntax-error
      _zsh_highlight_regex_add $k $(( j > $2 ? $2 : j )) $style
    elif (( $3 )) && [[ $s[k] == [\$@] && $s[k+1] == [[:alpha:]_{:] || $s[k] == '$' && $s[k+1] == [0-9] ]]; then
      if [[ $s[k+1] == '{' ]]; then
        while (( j < $2 )) && [[ $s[j] != '}' ]]; do (( j++ )); done
      else
        while (( j < $2 )) && [[ $s[j+1] == [[:alnum:]_:] ]]; do (( j++ )); done
      fi
      _zsh_highlight_regex_add $k $j perl-variable
    fi
  done
}

# Usage: `_zsh_highlight_regex_sed <depth> <script> <position>...`
#
# Colour a sed script (as GNU sed reads it), whose characters are at the given positions on the command line: its
# commands, addresses (line numbers and `/regex/`s), regexes, the `&` and `\1` etc in its replacements, labels, comments
# and `{ }` (carrying on from the depth given). Its text (e.g. the replacements, and what `a` `i` and `c` add) is left
# in the colour of the shell string it's in.
_zsh_highlight_regex_sed() {
  emulate -L zsh -o extended_glob
  local s=$2
  local -a pos=("${@:3}") brackets  # brackets: the `{`s still open
  local -i depth=$1 i j k n=$#2
  for (( i = 1; i <= n; i++ )); do
    case $s[i] in
      ([[:space:]]) ;;
      (\;) _zsh_highlight_regex_add $i $i sed-delimiter ;;
      ('#')
        for (( j = i; j < n; j++ )); do [[ $s[j+1] == $'\n' ]] && break; done
        _zsh_highlight_regex_add $i $j comment
        i=j ;;
      ('{')
        brackets+=($i)
        _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#brackets - 1) % 6 + 1 )) ;;
      ('}')
        if (( $#brackets )); then
          _zsh_highlight_regex_add $i $i bracket-depth-$(( (depth + $#brackets - 1) % 6 + 1 ))
          brackets[-1]=()
        else
          _zsh_highlight_regex_add $i $i bracket-unexpected
        fi ;;
      ([0-9\$])  # A line number, or `$` for the last line
        for (( j = i; j < n; j++ )); do [[ $s[j+1] == [0-9] ]] || break; done
        _zsh_highlight_regex_add $i $j sed-address
        i=j ;;
      ([,\!~+]) _zsh_highlight_regex_add $i $i sed-operator ;;  # E.g. `1,5` `/a/!` `0~2` `/a/,+3`
      ([/\\])  # A `/regex/` address (or `\%regex%` with another delimiter), with its flags (`I` `M`)
        k=i
        [[ $s[i] == '\' ]] && (( k++ ))
        _zsh_highlight_regex_sed_part $k regex
        for (( i = REPLY; i < n; i++ )); do [[ $s[i+1] == [IM] ]] || break; done
        (( i > REPLY )) && _zsh_highlight_regex_add $(( REPLY + 1 )) $i sed-command ;;
      (s)  # `s/regex/replacement/flags`, the flags being e.g. `g` `2` `I`, or `w` and a file to write to
        _zsh_highlight_regex_add $i $i sed-command
        _zsh_highlight_regex_sed_part $(( i + 1 )) regex
        _zsh_highlight_regex_sed_part $REPLY replacement
        for (( i = REPLY; i < n; i++ )); do [[ $s[i+1] == [gpiImMe0-9] ]] || break; done
        (( i > REPLY )) && _zsh_highlight_regex_add $(( REPLY + 1 )) $i sed-command
        if [[ $s[i+1] == w ]]; then
          _zsh_highlight_regex_add $(( i + 1 )) $(( i + 1 )) sed-command
          for (( ; i < n; i++ )); do [[ $s[i+1] == $'\n' ]] && break; done
        fi ;;
      (y)  # `y/abc/xyz/`
        _zsh_highlight_regex_add $i $i sed-command
        _zsh_highlight_regex_sed_part $(( i + 1 )) text
        _zsh_highlight_regex_sed_part $REPLY text
        i=$REPLY ;;
      ([aicrRwWe])  # Followed by text, a file or a command, up to the end of the line (with `\` continuing it)
        _zsh_highlight_regex_add $i $i sed-command
        for (( ; i < n; i++ )); do
          [[ $s[i+1] == $'\n' ]] && break
          [[ $s[i+1] == '\' ]] && (( i++ ))
        done ;;
      ([btT:])  # A label, after `:`, or after `b` `t` `T` to jump to it
        _zsh_highlight_regex_add $i $i sed-command
        for (( j = i; j < n; j++ )); do [[ $s[j+1] == [[:blank:]] ]] || break; done
        for (( k = j; k < n; k++ )); do [[ $s[k+1] == [\;$'\n'[:blank:]] ]] && break; done
        (( k > j )) && _zsh_highlight_regex_add $(( j + 1 )) $k sed-label
        i=k ;;
      ([dDgGhHlLnNpPqQxzF=]) _zsh_highlight_regex_add $i $i sed-command ;;
    esac
  done
}

# Colour the part of an `s` or `y` command, or `/regex/` address, in the script of _zsh_highlight_regex_sed (in its
# variables) whose delimiter is at $1: a regex, a replacement, or text. Put the position of its closing delimiter in
# $REPLY (or of the script's end, if it's unclosed).
_zsh_highlight_regex_sed_part() {
  local -i k=$1 j end
  local delimiter=$s[$1] char style
  for (( j = k + 1; j <= n; j++ )); do
    [[ $s[j] == '\' ]] && { (( j++ )); continue }
    [[ $s[j] == "$delimiter" ]] && break
  done
  (( end = j > n ? n : j - 1 ))
  if (( k <= n )) && [[ $delimiter != [[:space:]] ]]; then
    _zsh_highlight_regex_add $k $k sed-delimiter
    (( j <= n )) && _zsh_highlight_regex_add $j $j sed-delimiter
  fi
  case $2 in
    (regex) _zsh_highlight_regex_pattern sed $(( depth + $#brackets )) "$s[k+1,end]" "${(@)pos[k+1,end]}" ;;
    # A replacement's `&` and `\1` etc are the match and its groups, and its `\L` `\U` `\l` `\u` `\E` convert the case.
    (*)
      for (( k = k + 1; k <= end; k++ )); do
        char=$s[k]
        if [[ $char == '\' ]] && (( k < end )); then
          [[ $2 == replacement && $s[k+1] == [0-9] ]] && style=sed-reference || style=sed-escape
          # Escapes of other letters silently give the letter (e.g. `\q` is `q`), as do those of other characters.
          if [[ $s[k+1] == [[:alpha:]] && $s[k+1] != [ntfvarc] ]]; then
            [[ $2 == replacement && $s[k+1] == [LlUuE] ]] || [[ $s[k+1] == [dox] && $s[k+2] == [[:xdigit:]] ]] ||
              style=syntax-error
          fi
          _zsh_highlight_regex_add $k $(( k + 1 )) $style
          (( k++ ))
        elif [[ $2 == replacement && $char == '&' ]]; then
          _zsh_highlight_regex_add $k $k sed-reference
        fi
      done ;;
  esac
  REPLY=$(( j > n ? n : j ))
}

# Colour `$s[$1,$2]` in style $3, given the positions on the command line of s's characters in $pos (both the caller's)
_zsh_highlight_regex_add() {
  _zsh_highlight_add_highlight $(( pos[$1] - 1 )) $pos[$2] $3
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

# Run these after main, so they can override main's colours (and regex after rainbow, as it needs rainbow's brackets,
# and selection last, as it needs everything else's colours).
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main pathunderline arithmetic parameter keywords separators rainbow regex selection)
