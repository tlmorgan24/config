set termguicolors
syntax on  " Syntax highlighting
colorscheme catppuccin_mocha
hi Comment gui=italic cterm=italic  " Italic comments, as in VS Code's Catppuccin theme

" zsh scripts' colours are adjusted to match my zsh command line and VS Code, in ~/.vim/after/syntax/zsh.vim. Other
" shell scripts (sh, bash) use the same zsh syntax rather than Vim's sh one, so all are coloured the same way (as in VS
" Code, which has one grammar for all of them). Their filetype stays sh, for everything else that depends on it.
augroup shellsyntax
  autocmd!
  autocmd FileType sh,bash setlocal syntax=zsh
augroup END

" Go: turn on the extra highlighting in Vim's Go syntax (/usr/share/vim/vim91/syntax/go.vim), all off by default. Their
" colours are adjusted to match VS Code in ~/.vim/after/syntax/go.vim. Not turned on: go_highlight_fields (VS Code
" doesn't colour fields), and the error highlighting of whitespace.
let g:go_highlight_functions = 1  " Names in func declarations, and receiver types
" Parameter names, in the declaration only (VS Code also knows them in the body).
let g:go_highlight_function_parameters = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_types = 1  " Names in type declarations, and Foo{ composite literals
let g:go_highlight_extra_types = 1  " A few common library types, e.g. io.Reader, context.Context
let g:go_highlight_operators = 1
let g:go_highlight_format_strings = 0  " On by default, but VS Code leaves `%d` etc the colour of the string.

set number  " Line numbers (only one space away from start of line, unfortunately no way to customise spacing)
hi LineNr ctermfg=8  " Very low contrast with background, helps prevent line numbers from intruding on actual text.

" Indentation: default of 4 spaces per indent level
set expandtab  " Insert spaces rather than tab characters.
set tabstop=4  " Width of an indent level (and of a tab character)
set shiftwidth=0  " 0 means use tabstop, so indenting with `>`, `<`, Tab, Cmd+] etc. moves by one tabstop.

" Per-language indentation, mirroring the language-specific settings in VS Code's settings.json. Vim detects each file's
" type from its name/extension (e.g. `*.ts` is typescript, .zshrc is zsh).
augroup indentation
  autocmd!
  " The only file in VS Code's files.associations that vim doesn't already detect as a shell script.
  autocmd BufNewFile,BufRead .bash_login setfiletype sh
  " Tabs rather than spaces
  autocmd FileType go,make setlocal noexpandtab
  " 2 spaces
  autocmd FileType sh,bash,zsh,html,css,json,jsonc,yaml,xml,graphql,javascript,javascriptreact,typescript,typescriptreact setlocal tabstop=2
augroup END

" Normal mode: block cursor (there is an unfortunate ~1s delay before the cursor changes on many terminals, but Ghostty
" is instant).
let &t_EI = "\<Esc>[2 q"
let &t_SI = "\<Esc>[5 q"  " Insert mode: blinking bar cursor
let &t_SR = "\<Esc>[4 q"  " Replace mode: underline cursor
" Vim only sends the above on a change of mode, so also send the block cursor on startup (and on returning from `:!`).
" Otherwise vim starts with the shell's cursor (a line in VS Code, and in Ghostty, whose shell integration resets it to
" the default shape set in its config before each command).
let &t_ti .= "\<Esc>[2 q"
" On exit (and on going to `:!`), give the cursor back in the terminal's default shape (a line, as set in VS Code's
" settings.json and Ghostty's config), rather than leaving Vim's block for the program that ran Vim (e.g. Claude Code
" after cmd+e).
let &t_te .= "\<Esc>[0 q"
" Visual mode (all three kinds): blinking bar cursor, as in insert mode. Vim has no t_ option for visual mode, so send
" the cursor codes on entering it, and on returning to normal mode (from visual, or via e.g. `:` from visual).
augroup visualcursor
  autocmd!
  autocmd ModeChanged *:[vV\x16]* call echoraw("\<Esc>[5 q")
  autocmd ModeChanged *:n call echoraw("\<Esc>[2 q")
augroup END

" IMPORTANT: it seems .vimrc keymaps are really brittle. You CANNOT add comments to the end of the keymap lines, or they
" break. For e.g. ctrl+A and ctrl+E, you MUST use `<Char-0x01>` and `<Char-0x05>`. If you use `<C-A>` and `<C-E>`, even
" in addition, everything breaks.

" Enable use of mouse to move cursor and drag to select (automatically enters visual mode). Can still select using
" terminal itself with shift + drag.
set mouse=a
" With the above, dragging in insert mode remembers you were in insert mode and returns you there afterwards. This is
" not desirable (e.g. want d to always take you to normal mode), so explicitly go into the standard visual mode (also
" making sure not to shift the cursor).
inoremap <LeftDrag> <Cmd>let g:drag_pos = getcurpos()<CR><Esc><Cmd>call setpos('.', g:drag_pos)<CR><LeftDrag>

" Backspace in visual mode: delete selection and enter insert mode (like c, rather than the default d).
xnoremap <BS> c

" Left/Right at the start/end of a line: move to the end/start of the previous/next line, in all modes (< and > for
" normal and visual mode, [ and ] for insert and replace mode). Vim's default is b,s (Backspace and Space).
set whichwrap+=<,>,[,]

" Alt + Left: move back a word.
nnoremap <Esc>b b
inoremap <Esc>b <C-o>b
xnoremap <Esc>b b

" Alt + Right: move forward a word.
nnoremap <Esc>f w
inoremap <Esc>f <C-o>w
xnoremap <Esc>f w

" Cmd + Left / Ctrl-A: move to start of line (first non-blank character).
nnoremap <Char-0x01> ^
inoremap <Char-0x01> <C-o>^
xnoremap <Char-0x01> ^

" Cmd + Right / Ctrl-E: move to end of line.
nnoremap <Char-0x05> $
inoremap <Char-0x05> <C-o>$
xnoremap <Char-0x05> $

" Cmd + Up: move to start of file.
nnoremap <Esc>[1;9A gg
inoremap <Esc>[1;9A <C-o>gg
xnoremap <Esc>[1;9A gg

" Cmd + Down: move to end of file.
nnoremap <Esc>[1;9B G$
inoremap <Esc>[1;9B <C-o>G<End>
xnoremap <Esc>[1;9B G$

" Alt + Backspace: delete previous word (if in insert mode). `<Esc><BS>` and `<Esc><Char-0x7f>` do not work.
inoremap <M-BS> <C-w>

" Cmd + Backspace: delete to start of line (requires this complex approach to prevent leftover character).
inoremap <expr> <Char-0x15> "\<C-g>u" . repeat("\<BS>", strchars(strpart(getline('.'), 0, col('.') - 1)))

" Shift + Left/Right: extend selection by one character (entering visual mode if not already there). Uses the arrow keys
" rather than h/l so that they wrap to the previous/next line (see whichwrap above).
nnoremap <S-Left>  v<Left>
nnoremap <S-Right> v<Right>
inoremap <S-Left>  <C-o>v<Left>
inoremap <S-Right> <C-o>v<Right>
xnoremap <S-Left>  <Left>
xnoremap <S-Right> <Right>

" Alt + Shift + Left/Right: extend selection by one word (entering visual mode if not already there).
nnoremap <M-S-Left>  vb
nnoremap <M-S-Right> ve
inoremap <M-S-Left>  <C-o>vb
inoremap <M-S-Right> <C-o>ve
xnoremap <M-S-Left>  b
xnoremap <M-S-Right> e

" Cmd + Shift + Left/Right: extend selection to start/end of line (entering visual mode if not already there).
nnoremap <Esc>[1;10D v^
nnoremap <Esc>[1;10C v$
inoremap <Esc>[1;10D <C-o>v^
inoremap <Esc>[1;10C <C-o>v$
xnoremap <Esc>[1;10D ^
xnoremap <Esc>[1;10C $

" Shift + Up/Down: extend selection by one line.
nnoremap <S-Up> vk
nnoremap <S-Down> vj
inoremap <S-Up> <C-o>vk
inoremap <S-Down> <C-o>vj
xnoremap <S-Up> k
xnoremap <S-Down> j

" Cmd + Shift + Up: extend selection to start of file.
nnoremap <Esc>[1;10A vgg
inoremap <Esc>[1;10A <C-o>vgg
xnoremap <Esc>[1;10A gg

" Cmd + Shift + Down: extend selection to end of file.
nnoremap <Esc>[1;10B vG$
inoremap <Esc>[1;10B <C-o>vG$
xnoremap <Esc>[1;10B G$

" Cmd + z: undo.
nnoremap <Char-0x1f> u
inoremap <Char-0x1f> <C-o>u
xnoremap <Char-0x1f> <Esc>u

" Cmd + Shift + z: redo.
nnoremap <Esc>/ <C-r>
inoremap <Esc>/ <C-o><C-r>
xnoremap <Esc>/ <Esc><C-r>

" Cmd + c: copy visual selection to system clipboard (leaves vim registers untouched). In Ghostty / VS Code, I actually
" only send this sequence by pressing cmd+shift+c, because cmd+c is already used by them to mean copy TERMINAL's
" selection.
xnoremap <Esc>[99;9u <Cmd>call system('pbcopy', getregion(getpos('v'), getpos('.'), #{type: mode()}) + (mode() ==# 'V' ? [''] : []))<CR>

" Cmd + x: cut visual selection to system clipboard and enter insert mode (leaves vim registers untouched).
xnoremap <Esc>[120;9u <Cmd>call system('pbcopy', getregion(getpos('v'), getpos('.'), #{type: mode()}) + (mode() ==# 'V' ? [''] : []))<CR>"_c

" Cmd + ]: indent right by one level (current line in NORMAL/INSERT mode, selected lines in VISUAL mode, keeping the
" selection).
nnoremap <Esc>[93;9u >>
inoremap <Esc>[93;9u <C-t>
xnoremap <Esc>[93;9u >gv

" Cmd + [: indent left by one level (as for Cmd + ]).
nnoremap <Esc>[91;9u <<
inoremap <Esc>[91;9u <C-d>
xnoremap <Esc>[91;9u <gv

" Tab / Shift + Tab in VISUAL mode: indent selected lines right/left by one level, keeping the selection. Tab is not
" remapped in NORMAL mode, because it is the same byte as Ctrl+I (jump forward), and in INSERT mode it already inserts
" an indent.
xnoremap <Tab> >gv
xnoremap <S-Tab> <gv

" Shift + Tab in INSERT mode: indent current line left by one level.
inoremap <S-Tab> <C-d>
