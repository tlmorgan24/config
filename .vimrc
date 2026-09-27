syntax on  " syntax highlighting
set number  " line numbers
hi LineNr ctermbg=0 ctermfg=7  " line numbers are only one space away from start of line, so colouring helps distinguish

let &t_EI = "\<Esc>[2 q"  " Normal mode: block cursor
let &t_SI = "\<Esc>[6 q"  " Insert mode: bar cursor
let &t_SR = "\<Esc>[4 q"  " Replace mode: underline cursor
