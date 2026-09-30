syntax on  " syntax highlighting
set number  " line numbers (only one space away from start of line, unfortunately no way to customise spacing)
hi LineNr ctermfg=8  " very low contrast with background, helps prevent line numbers from intruding on actual text

let &t_EI = "\<Esc>[2 q"  " Normal mode: block cursor
let &t_SI = "\<Esc>[6 q"  " Insert mode: bar cursor
let &t_SR = "\<Esc>[4 q"  " Replace mode: underline cursor
