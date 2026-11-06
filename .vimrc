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
" and Kitty are instant).
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
" VS Code's terminal reports a drag as soon as the mouse moves with the button held, even within the cell clicked (as
" happens in most clicks on a trackpad), where Ghostty and kitty wait until it reaches another cell. So ignore drags
" until the mouse leaves the clicked cell, otherwise such a click would leave insert mode (by the insert mode drag
" below), or select a character in normal mode.
let g:click_pos = {}
nnoremap <LeftMouse> <Cmd>let g:click_pos = getmousepos()<CR><LeftMouse>
inoremap <LeftMouse> <Cmd>let g:click_pos = getmousepos()<CR><LeftMouse>
xnoremap <expr> <LeftMouse> <SID>VisualClick()
nnoremap <expr> <LeftDrag> <SID>Drag("\<LeftDrag>")
" With `mouse=a`, dragging in insert mode remembers you were in insert mode and returns you there afterwards. This is
" not desirable (e.g. want d to always take you to normal mode), so explicitly go into the standard visual mode (also
" making sure not to shift the cursor).
inoremap <expr> <LeftDrag> <SID>Drag("\<Cmd>let g:drag_pos = getcurpos()\<CR>\<Esc>\<Cmd>call setpos('.', g:drag_pos)\<CR>\<LeftDrag>")
xnoremap <expr> <LeftDrag> <SID>Drag("\<LeftDrag>")
nnoremap <LeftRelease> <Cmd>call <SID>Release()<CR><LeftRelease>
inoremap <LeftRelease> <Cmd>call <SID>Release()<CR><LeftRelease>
xnoremap <LeftRelease> <Cmd>call <SID>Release()<CR><LeftRelease>

" Click in visual mode: extend the selection to the click (Vim's default ends visual mode and moves the cursor there,
" and its shift + click, which extends, is taken by the terminal; Vim also misreads it as shift + scroll down). Move the
" cursor to the clicked position without leaving visual mode (going out and back in with gv made the highlight flicker).
" Vim then ignores the drag that follows, as it never saw the click, so `s:Drag()` moves the cursor itself. A click in
" another window, or on a status line, keeps Vim's default.
let g:visual_clicked = 0  " Whether the button went down in `s:VisualClick()`, and is still down
function! s:VisualClick()
  call s:StopAutoScroll()
  let g:click_pos = getmousepos()
  let g:visual_clicked = g:click_pos.winid == win_getid() && g:click_pos.line > 0
  if !g:visual_clicked
    return "\<LeftMouse>"
  endif
  return s:MoveToMouse(g:click_pos)
endfunction

" Keys that move the cursor to the mouse at `pos`.
function! s:MoveToMouse(pos)
  let end = s:MouseEnd(a:pos)
  let g:visual_end = empty(end) ? [0, a:pos.line, max([1, a:pos.column]), 0] : end
  return "\<Cmd>call setpos('.', g:visual_end)\<CR>"
endfunction

" Where the mouse at `pos` should put the selection's end, if not where Vim's click puts the cursor (returns [] then).
" Past the end of a line, Vim's click lands on the last character, where a drag lands after it (selecting the line
" break, as `$` does), so do as the drag does. Below the last line (on the `~` rows), Vim lands in the last line at the
" mouse's column, where the end of the file is wanted.
function! s:MouseEnd(pos)
  let buf = winbufnr(a:pos.winid)
  let last = line('$', a:pos.winid)
  let lastlen = len(getbufline(buf, last)[0])
  let lastrow = screenpos(a:pos.winid, last, max([1, lastlen])).row  " 0 if the last line is off screen
  if a:pos.line == last && lastrow > 0 && a:pos.screenrow > lastrow
    return [0, last, lastlen + 1, 0]
  elseif a:pos.column > len(getbufline(buf, a:pos.line)[0])
    return [0, a:pos.line, a:pos.column, 0]
  endif
  return []
endfunction

let s:sid = expand('<SID>')

function! s:Drag(keys)
  let pos = getmousepos()
  if !empty(g:click_pos) && pos.screenrow == g:click_pos.screenrow && pos.screencol == g:click_pos.screencol
    return ''
  endif
  let g:click_pos = {}  " The mouse has left the clicked cell, so pass on all drags until the next click.
  call s:UpdateAutoScroll(pos)
  if g:visual_clicked && mode() =~# "^[vV\x16]"
    " Off the window (e.g. on the status line), leave the cursor to autoscroll.
    return pos.winid == win_getid() && pos.line > 0 ? s:MoveToMouse(pos) : ''
  endif
  " Dragging below the last line extends to the end of the file, as a click there does.
  return a:keys . "\<Cmd>call " . s:sid . "DragEnd()\<CR>"
endfunction

function! s:DragEnd()
  let pos = getmousepos()
  if pos.winid == win_getid() && pos.line > 0 && mode() =~# "^[vV\x16]"
    let end = s:MouseEnd(pos)
    if !empty(end)
      call setpos('.', end)
    endif
  endif
endfunction

" Drag to the top or bottom row of the window (or beyond it, e.g. onto the status line): keep scrolling up or down, a
" line at a time, extending the selection, until the mouse moves off that row or is released. Vim on its own only
" scrolls when the mouse is beyond the window and moves, and a terminal sends nothing while the mouse is still.
let s:autoscroll_ms = 50
let s:autoscroll_timer = -1
let s:autoscroll_dir = 0

function! s:UpdateAutoScroll(pos)
  let top = win_screenpos(0)[0]
  let s:autoscroll_dir = a:pos.screenrow <= top ? -1 : a:pos.screenrow >= top + winheight(0) - 1 ? 1 : 0
  if s:autoscroll_dir == 0
    call s:StopAutoScroll()
  elseif s:autoscroll_timer == -1
    let s:autoscroll_timer = timer_start(s:autoscroll_ms, function('s:AutoScrollStep'), {'repeat': -1})
  endif
endfunction

function! s:AutoScrollStep(timer)
  " The drag has ended without a release reaching Vim (e.g. Esc pressed mid-drag).
  if mode() !~# "^[vV\x16]"
    call s:StopAutoScroll()
    return
  endif
  if s:autoscroll_dir < 0 ? line('.') > 1 : line('.') < line('$')
    " Moving the cursor past the window's edge scrolls by a line ('scrolloff' is 0), and keeps the column of the mouse.
    execute 'normal!' s:autoscroll_dir < 0 ? 'k' : 'j'
    redraw
  endif
endfunction

function! s:Release()
  let g:visual_clicked = 0
  call s:StopAutoScroll()
endfunction

function! s:StopAutoScroll()
  if s:autoscroll_timer != -1
    call timer_stop(s:autoscroll_timer)
    let s:autoscroll_timer = -1
  endif
endfunction

" Scroll in visual or insert mode: leave the cursor where it is. Vim keeps the cursor on screen, so scrolling it off
" moves it, which in visual mode moves the selection's moving end, and in insert mode where typing goes. So while the
" cursor's place is off screen, remember it and hide the cursor (and in visual mode, show the remembered selection with
" a match in place of Vim's Visual highlight). Put the cursor back when scrolling brings its place back on screen, or
" before the next key acts on it (Vim then scrolls back to it). A mouse key leaves the cursor where it is, as the mouse
" works on what is on screen. Not done in normal mode, where keys like H, zz and Ctrl-D work on the screen or cursor as
" they are after the scroll.
"
" Every wheel key counts as scrolling, including horizontal ones, which trackpads send among vertical ones even when
" scrolling straight up or down.
for s:wheel in ['Up', 'Down', 'Left', 'Right']
  for s:mod in ['', 'S-', 'C-']
    for s:mapmode in ['x', 'i']
      execute s:mapmode . 'noremap <' . s:mod . 'ScrollWheel' . s:wheel . '> <Cmd>call <SID>BeforeScroll()<CR><' .
            \ s:mod . 'ScrollWheel' . s:wheel . '><Cmd>call <SID>AfterScroll()<CR>'
    endfor
  endfor
endfor
" While the cursor's place is off screen: its window and saved `t_ve`, and in visual mode the match showing the
" selection and the saved Visual highlight
let s:scrolled = {}
let s:scrolled_pos = []

augroup scrolledaway
  autocmd!
  autocmd KeyInputPre * call s:KeyWhileScrolled()
  autocmd ModeChanged [vV\x16iR]*:* call s:EndScrolled(0)
augroup END

function! s:BeforeScroll()
  if empty(s:scrolled)
    let s:scrolled_pos = getcurpos()
  endif
endfunction

function! s:AfterScroll()
  if s:scrolled_pos[1] >= line('w0') && s:scrolled_pos[1] <= line('w$')
    call s:EndScrolled(1)
  elseif empty(s:scrolled) && getcurpos() != s:scrolled_pos
    call s:StartScrolled()
  endif
endfunction

function! s:StartScrolled()
  let s:scrolled = {'win': win_getid(), 't_ve': &t_ve}
  if mode() =~# "^[vV\x16]"
    call s:ShowScrolledSelection()
  endif
  let &t_ve = ''  " Vim then leaves the cursor hidden after each redraw.
  call echoraw(&t_vi)
endfunction

function! s:ShowScrolledSelection()
  let anchor = getpos('v')[1:2]
  let end = s:scrolled_pos[1:2]
  let [start, end] = anchor[0] < end[0] || anchor[0] == end[0] && anchor[1] <= end[1] ? [anchor, end] : [end, anchor]
  let [l1, c1, l2, c2] = start + end
  if mode() ==# 'V'
    let pattern = '\%>' . (l1 - 1) . 'l\%<' . (l2 + 1) . 'l\_.'
  elseif mode() ==# 'v'
    " `\_.` takes in the line break when the end is past the last character.
    let pattern = l1 == l2 ? '\%' . l1 . 'l\%>' . (c1 - 1) . 'c\%<' . (c2 + 1) . 'c\_.' :
          \ '\%' . l1 . 'l\%>' . (c1 - 1) . 'c\_.\|\%>' . l1 . 'l\%<' . l2 . 'l\_.\|' .
          \ '\%' . l2 . 'l\%<' . (c2 + 1) . 'c\_.'
  else
    let [v1, v2] = sort([virtcol(start), virtcol(end)], 'n')
    let pattern = '\%>' . (l1 - 1) . 'l\%<' . (l2 + 1) . 'l\%>' . (v1 - 1) . 'v' .
          \ (s:scrolled_pos[4] == v:maxcol ? '' : '\%<' . (v2 + 1) . 'v') . '.'
  endif
  let visual = hlget('Visual', v:true)[0]
  call hlset([extend(filter(copy(visual), 'v:key !=# "id"'), {'name': 'ScrolledVisual'})])
  let s:scrolled.match = matchadd('ScrolledVisual', pattern)
  let s:scrolled.visual = hlget('Visual')
  call hlset([{'name': 'Visual', 'cleared': v:true}])
endfunction

function! s:EndScrolled(restore_cursor)
  if empty(s:scrolled)
    return
  endif
  if a:restore_cursor && win_getid() == s:scrolled.win
    call setpos('.', s:scrolled_pos)
  endif
  if has_key(s:scrolled, 'match')
    silent! call matchdelete(s:scrolled.match, s:scrolled.win)  " Silent in case the window has since been closed.
    call hlset([{'name': 'Visual', 'cleared': v:true}] + s:scrolled.visual)
  endif
  let &t_ve = s:scrolled.t_ve
  call echoraw(&t_ve)
  let s:scrolled = {}
endfunction

" A typed key (or the first key of the mapping it triggers), before it is acted on.
function! s:KeyWhileScrolled()
  if empty(s:scrolled) || v:event.typedchar ==# ''
    return
  endif
  let key = keytrans(v:event.typedchar)
  if key !~# '^<\%([SC]-\)\=ScrollWheel\%(Up\|Down\|Left\|Right\)>$'
    call s:EndScrolled(key !~# 'Mouse\|Drag\|Release')
  endif
endfunction

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

" Cmd + s: save (only if changed) and quit, from NORMAL, INSERT or VISUAL mode.
nnoremap <Esc>[115;9u <Cmd>x<CR>
inoremap <Esc>[115;9u <Cmd>x<CR>
xnoremap <Esc>[115;9u <Cmd>x<CR>

" Tab / Shift + Tab in VISUAL mode: indent selected lines right/left by one level, keeping the selection. Tab is not
" remapped in NORMAL mode, because it is the same byte as Ctrl+I (jump forward), and in INSERT mode it already inserts
" an indent.
xnoremap <Tab> >gv
xnoremap <S-Tab> <gv

" Shift + Tab in INSERT mode: indent current line left by one level.
inoremap <S-Tab> <C-d>

" Command line (`:`, and also `/` and `?` searches): the same text editing shortcuts as in insert mode, where the command
" line has an equivalent. Cmd + Backspace (Ctrl-U) and Ctrl-E already do the same there by default.
"
" Alt + Left/Right: move back/forward a word, stopping where `b` and `w` do (the command line's own Shift + Left/Right
" only stop at spaces).
function! s:CmdWordLeft()
  let before = strpart(getcmdline(), 0, getcmdpos() - 1)
  call setcmdpos(max([match(before, '\%(\k\+\|\%(\k\@!\S\)\+\)\s*$'), 0]) + 1)
  return getcmdline()
endfunction

function! s:CmdWordRight()
  let after = strpart(getcmdline(), getcmdpos() - 1)
  call setcmdpos(getcmdpos() + matchend(after, '^\%(\k\+\|\%(\k\@!\S\)\+\)\=\s*'))
  return getcmdline()
endfunction

cnoremap <Esc>b <C-\>e<SID>CmdWordLeft()<CR>
cnoremap <Esc>f <C-\>e<SID>CmdWordRight()<CR>

" Cmd + Left / Ctrl-A: move to start of command line.
cnoremap <Char-0x01> <Home>

" Cmd + Up/Down: move to start/end of command line.
cnoremap <Esc>[1;9A <Home>
cnoremap <Esc>[1;9B <End>

" Alt + Backspace: delete previous word.
cnoremap <M-BS> <C-w>

" When a command starting with `:` is pasted onto an empty `:` command line (as when copying a command from elsewhere),
" drop the pasted `:`, as the command line already has one. A change counts as a paste if it takes an empty command line
" to more than one character at once, which typing can't.
function! s:DropPastedColon()
  let line = getcmdline()
  if s:cmdline_before ==# '' && line =~# '^:.'
    call setcmdline(line[1:], getcmdpos() - 1)
  endif
  let s:cmdline_before = getcmdline()
endfunction

augroup pastedcolon
  autocmd!
  autocmd CmdlineEnter : let s:cmdline_before = ''
  autocmd CmdlineChanged : call s:DropPastedColon()
augroup END
