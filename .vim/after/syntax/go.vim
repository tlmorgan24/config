" Additions to Vim's Go syntax highlighting (/usr/share/vim/vim91/syntax/go.vim, with the extra highlighting turned on in
" .vimrc), which runs before this, so Go is coloured as VS Code colours it (Catppuccin theme, with gopls' semantic tokens).
" Colours are from the Catppuccin Mocha palette.

" Function calls: blue, like function declarations, instead of yellow (types)
hi! link goFunctionCall Function
" Built-in functions (len, append etc): blue, like other functions, instead of flamingo
hi! link goBuiltins Function

" Built-in types (int, string, error etc), and true, false, nil and iota: mauve, as gopls marks them all as built in,
" instead of yellow (types) and peach (constants)
hi! link goType Keyword
hi! link goSignedInts Keyword
hi! link goUnsignedInts Keyword
hi! link goFloats Keyword
hi! link goComplexes Keyword
hi! link goBoolean Keyword
hi! link goPredefinedIdentifiers Keyword

" Other types: yellow, italic
hi goTypeStyle guifg=#f9e2af gui=italic cterm=italic
hi! link goTypeName goTypeStyle
hi! link goReceiverType goTypeStyle
hi! link goTypeConstructor goTypeStyle
hi! link goExtraType goTypeStyle

" Parameters: maroon, italic, instead of flamingo
hi goParamStyle guifg=#eba0ac gui=italic cterm=italic
hi! link goParamName goParamStyle

" case and default: mauve, like other keywords, instead of sapphire (labels)
hi! link goLabel Keyword
" Runes ('x'): green, like strings, instead of teal (characters)
hi! link goCharacter String
