set termguicolors
syntax on  " syntax highlighting
colorscheme catppuccin_mocha
set number  " line numbers (only one space away from start of line, unfortunately no way to customise spacing)
hi LineNr ctermfg=8  " very low contrast with background, helps prevent line numbers from intruding on actual text

let &t_EI = "\<Esc>[2 q"  " Normal mode: block cursor
let &t_SI = "\<Esc>[6 q"  " Insert mode: bar cursor
let &t_SR = "\<Esc>[4 q"  " Replace mode: underline cursor

" IMPORTANT
" It seems .vimrc keymaps are really brittle
" You CANNOT add comments to the end of the keymap lines, or they break
" For e.g. ctrl+A and ctrl+E, you MUST use <Char-0x01> and <Char-0x05>
" If you use <C-A> and <C-E>, even in addition, everything breaks

" enable use of mouse to move cursor and drag to select (automatically enters visual mode)
" can still select using terminal itself with shift + drag
set mouse=a
" The above remembers if you were in insert mode and returns you there afterwards
" This is not desirable (e.g. want d to always take you to normal mode)
" The below explicitly leaves goes into the standard visual mode (also makes sure not to shift the cursor)
inoremap <LeftDrag> <Cmd>let g:drag_pos = getcurpos()<CR><Esc><Cmd>call setpos('.', g:drag_pos)<CR><LeftDrag>

" Backspace in visual mode: delete selection and enter insert mode (like c, rather than the default d)
xnoremap <BS> c

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

" Cmd + Up: move to start of file
nnoremap <Esc>[1;9A gg
inoremap <Esc>[1;9A <C-o>gg
xnoremap <Esc>[1;9A gg

" Cmd + Down: move to end of file
nnoremap <Esc>[1;9B G$
inoremap <Esc>[1;9B <C-o>G<End>
xnoremap <Esc>[1;9B G$

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

" Shift + Up/Down: extend selection by one line
nnoremap <S-Up> vk
nnoremap <S-Down> vj
inoremap <S-Up> <C-o>vk
inoremap <S-Down> <C-o>vj
xnoremap <S-Up> k
xnoremap <S-Down> j

" Cmd + Shift + Up: extend selection to start of file
nnoremap <Esc>[1;10A vgg
inoremap <Esc>[1;10A <C-o>vgg
xnoremap <Esc>[1;10A gg

" Cmd + Shift + Down: extend selection to end of file
nnoremap <Esc>[1;10B vG$
inoremap <Esc>[1;10B <C-o>vG$
xnoremap <Esc>[1;10B G$

" Cmd + z: undo
nnoremap <Char-0x1f> u
inoremap <Char-0x1f> <C-o>u
xnoremap <Char-0x1f> <Esc>u

" Cmd + Shift + z: redo
nnoremap <Esc>/ <C-r>
inoremap <Esc>/ <C-o><C-r>
xnoremap <Esc>/ <Esc><C-r>

" Cmd + c: copy visual selection to system clipboard (leaves vim registers untouched)
" in Ghostty / VS Code, I actually only send this sequence by pressing cmd+shift+c, because cmd+c is already used by them to mean copy TERMINAL's selection
xnoremap <Esc>[99;9u <Cmd>call system('pbcopy', getregion(getpos('v'), getpos('.'), #{type: mode()}) + (mode() ==# 'V' ? [''] : []))<CR>

" Cmd + x: cut visual selection to system clipboard and enter insert mode (leaves vim registers untouched)
xnoremap <Esc>[120;9u <Cmd>call system('pbcopy', getregion(getpos('v'), getpos('.'), #{type: mode()}) + (mode() ==# 'V' ? [''] : []))<CR>"_c
