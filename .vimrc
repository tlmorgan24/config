syntax on  " syntax highlighting
set number  " line numbers (only one space away from start of line, unfortunately no way to customise spacing)
hi LineNr ctermfg=8  " very low contrast with background, helps prevent line numbers from intruding on actual text

let &t_EI = "\<Esc>[2 q"  " Normal mode: block cursor
let &t_SI = "\<Esc>[6 q"  " Insert mode: bar cursor
let &t_SR = "\<Esc>[4 q"  " Replace mode: underline cursor

" enable use of mouse to move cursor and drag to select (automatically enters visual mode)
" can still select using terminal itself with shift + drag
set mouse=a

" IMPORTANT
" It seems .vimrc keymaps are really brittle
" You CANNOT add comments to the end of the keymap lines, or they break
" For e.g. ctrl+A and ctrl+E, you MUST use <Char-0x01> and <Char-0x05>
" If you use <C-A> and <C-E>, even in addition, everything breaks

" Alt + Left: move back a word
nnoremap <Esc>b b
inoremap <Esc>b <C-o>b
xnoremap <Esc>b b

" Alt + Right: move forward a word
nnoremap <Esc>f w
inoremap <Esc>f <C-o>w
xnoremap <Esc>f w

" Cmd + Left / Ctrl-A: move to start of line (first non-blank character)
nnoremap <Char-0x01> ^
inoremap <Char-0x01> <C-o>^
xnoremap <Char-0x01> ^

" Cmd + Right / Ctrl-E: move to end of line
nnoremap <Char-0x05> $
inoremap <Char-0x05> <C-o>$
xnoremap <Char-0x05> $

" Alt + Backspace: delete previous word (if in insert mode)
" <Esc><BS> and <Esc><Char-0x7f> do not work
inoremap <M-BS> <C-w>

" Cmd + Backspace: delete to start of line (requires this complex approach to prevent leftover character)
inoremap <expr> <Char-0x15> "\<C-g>u" . repeat("\<BS>", strchars(strpart(getline('.'), 0, col('.') - 1)))

" Shift + Left/Right: extend selection by one character (entering visual mode if not already there)
nnoremap <S-Left>  vh
nnoremap <S-Right> vl
inoremap <S-Left>  <C-o>vh
inoremap <S-Right> <C-o>vl
xnoremap <S-Left>  h
xnoremap <S-Right> l

" Alt + Shift + Left/Right: extend selection by one word (entering visual mode if not already there)
nnoremap <M-S-Left>  vb
nnoremap <M-S-Right> ve
inoremap <M-S-Left>  <C-o>vb
inoremap <M-S-Right> <C-o>ve
xnoremap <M-S-Left>  b
xnoremap <M-S-Right> e

" Cmd + Shift + Left/Right: extend selection to start/end of line (entering visual mode if not already there)
nnoremap <Esc>[1;10D v^
nnoremap <Esc>[1;10C v$
inoremap <Esc>[1;10D <C-o>v^
inoremap <Esc>[1;10C <C-o>v$
xnoremap <Esc>[1;10D ^
xnoremap <Esc>[1;10C $

" Cmd + z: undo
nnoremap <Char-0x1f> u
inoremap <Char-0x1f> <C-o>u
xnoremap <Char-0x1f> <Esc>u

" Cmd + Shift + z: redo
nnoremap <Esc>/ <C-r>
inoremap <Esc>/ <C-o><C-r>
xnoremap <Esc>/ <Esc><C-r>