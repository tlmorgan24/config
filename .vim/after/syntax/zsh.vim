" Additions to Vim's zsh syntax highlighting (/usr/share/vim/vim91/syntax/zsh.vim), which runs before this, so shell scripts
" (which all use the zsh syntax, see .vimrc) are coloured as my zsh command line is (~/.zsh/syntax-highlighting.zsh) and as
" VS Code colours shell scripts.
" Colours are from the Catppuccin Mocha palette, assigned as per Catppuccin's style guide.

" Commands: blue (the guide's colour for functions)
hi! link zshCommands Function
hi! link zshFunction Function
" Vim's zsh syntax only knows the builtins (zshCommands above), so any other command is found by its position: a word at the
" start of a line (unless the line before ends in a \), after ; | & ( { or `, after a case pattern's ), or after a keyword
" or precommand that's followed by a command (if, then, sudo etc), skipping any var=value assignments before it (whose
" values are taken to have no brackets or `, so that x=$(cmd arg) isn't taken as an assignment followed by a command). A word
" followed by ) without a space (e.g. b in a case pattern b|c)) isn't one. Keywords (if, echo etc) take priority over this, so
" keep their own colours
syn match zshCommandName '\v%(%(%(%(\\\n)@<!^|[;&|{`]|%(\=)@<!\(|^\s*\(?[^()[:space:]][^()]*\))\s*|<%(if|then|else|elif|while|until|do|noglob|nocorrect|exec|command|builtin|time|doas|nice|pkexec|sudo|stdbuf|nohup|setsid|env|ionice)\s+|[!]\s+)%(\h\w*%(\[[^]]*\])?\+?\=[^[:space:]()`]*\s+)*)@<=[[:alnum:]_.~/][[:alnum:]_.~/+:@%,-]*%(\S*\))@!\ze%(\s|$|[;&|`])'
" a command on its own in $( ) or ( ), e.g. $(pwd). Not a word followed by ) elsewhere, as that's a case pattern
syn match zshCommandName '\v%(\$?\(\s*)@<=[[:alnum:]_.~/][[:alnum:]_.~/+:@%,-]*\ze\)'
hi! link zshCommandName Function
" precommands (as zsh-syntax-highlighting's list of them): blue, italic
syn keyword zshPrecommand doas nice pkexec sudo stdbuf nohup setsid env ionice
hi zshPrecommandStyle guifg=#89b4fa gui=italic cterm=italic
hi! link zshPrecommand zshPrecommandStyle

" Keywords: mauve. return, break, continue and export are builtins in Vim's zsh syntax (keywords defined later win)
syn keyword zshKeywordCommand return break continue export
hi! link zshKeywordCommand Keyword
hi! link zshTypes Keyword " local, typeset etc, instead of yellow (types)
" the in of a for loop (case's in is already a keyword)
syn match zshForIn '\v%(<%(for|foreach|select)\s+%(\h\w*\s+)+)@<=in>'
hi! link zshForIn Keyword

" Options (-la, --color=auto): peach
" (an --option=value's value stops at any quote, $, ` or bracket, so strings and the like in it are coloured as usual)
syn match zshCommandOption #\v%(\s)@<=--?%([[:alnum:]][[:alnum:]_-]*%(\=[^[:space:]'"`$()]*)?)?\ze%([[:space:];&|)'"`$]|$)#
hi! link zshCommandOption Constant

" Operators: sky. | and redirections already are (as zshRedir)
hi! link zshOperator Operator " && || &
" ; (and case's ;;): overlay 2 (punctuation, as in other languages)
syn match zshStatementTerminator ';;\='
hi! link zshStatementTerminator Delimiter
" the = in var=value, if the var=value is at the start of a command or after export, local etc
syn match zshAssignOperator '\v%(%(%(^|[;&|{`]|%(\=)@<!\()\s*|<%(if|then|else|elif|while|until|do|export|local|typeset|declare|readonly|integer|float|private|env)%(\s+-\S+)*\s+)%(\h\w*%(\[[^]]*\])?\+?\=[^[:space:]()`]*\s+)*\h\w*%(\[[^]]*\])?)@<=\+?\='
hi! link zshAssignOperator Operator

" Variables: rosewater (the guide's colour for macros, which like variables get replaced by something else before running),
" instead of pink
hi zshParameter guifg=#f5e0dc
hi! link zshDereferencing zshParameter " $var, $1, $? etc
" ${var}: the same regions as Vim's zsh syntax, but with the ${ } as zshParameterDelim instead of zshSubstDelim, which is also
" the $( ) around $(command). zshSubst comes last as Vim's does, so that's the one used outside strings
syn region zshSubstQuoted matchgroup=zshParameterDelim start='\${' skip='\\}' end='}' contains=@zshSubst,zshBrackets,zshQuoted fold
syn region zshSubst matchgroup=zshParameterDelim start='\${' skip='\\}' end='}' contains=@zshSubst,zshBrackets,zshQuoted,zshString fold
hi! link zshParameterDelim zshParameter
hi! link zshSubst zshParameter " the inside of ${ } ($( ) and $(( )) are transparent, so take the colours of what's inside them)
" Positional parameters ($1, ${1}, ${1:-default}, $@): maroon, italic (the guide's colour for parameters, styled as VS Code does
" them in all languages). Defined after Vim's $variables and ${ }, so they take priority
syn match zshPositional '\$\%(\d\+\|@\)'
syn cluster zshDerefs add=zshPositional
syn region zshPositionalSubst matchgroup=zshPositionalSubst start='\${\ze\s*\d' skip='\\}' end='}' contains=@zshSubst,zshBrackets,zshQuoted,zshString fold
syn cluster zshSubst add=zshPositionalSubst
syn cluster zshSubstQuoted add=zshPositionalSubst
hi zshPositionalStyle guifg=#eba0ac gui=italic cterm=italic
hi! link zshPositional zshPositionalStyle
hi! link zshPositionalSubst zshPositionalStyle
" the $( ), ` ` and $(( )) around commands and arithmetic: overlay 2 (delimiters), instead of pink
hi! link zshSubstDelim Delimiter
hi! link zshOldSubst NONE " the inside of ` `: as any other code, instead of as zshSubst
" <(command), >(command) and =(command) (=( only at the start of a word, as var=( is an array): with the same delimiters,
" instead of < and > being redirections
syn region zshProcessSubst matchgroup=zshSubstDelim transparent start='[<>](\|\%(^\|\s\)\@1<==(' skip='\\)' end=')' contains=TOP

" Arithmetic, inside (( )) and $(( )), which Vim's zsh syntax only colours the numbers and $variables of: variables without a $
" (rosewater) and operators (sky)
syn match zshMathVariable '\<\h\w*\>' contained containedin=zshMathSubst
hi! link zshMathVariable zshParameter
syn match zshMathOperator '[-+*/%<>=!&|^~?:,]\+' contained containedin=zshMathSubst
hi! link zshMathOperator Operator
" ( ) inside arithmetic: overlay 2, with the same colouring inside them (instead of Vim's zshParentheses, which also has
" subshells' ( ), so can't contain the above)
syn region zshMathParentheses matchgroup=Delimiter start='(' skip='\\)' end=')' contained containedin=zshMathSubst
      \ contains=zshMathParentheses,zshMathVariable,zshMathOperator,zshNumber,@zshDerefs,@zshSubst

" Globbing (* and ? in arguments, and (#...) flags): pink (the guide's colour for patterns)
syn match zshGlobChar '[*?]'
hi! link zshGlobChar Special
hi! link zshGlob Special " instead of as zshSubst
