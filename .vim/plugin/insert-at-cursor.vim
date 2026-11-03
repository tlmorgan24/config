vim9script
# Start in insert mode at the cursor when cmd+e opens Vim on a zsh command line (see edit-command-line-highlighted in
# .zshrc) or a Claude Code prompt (chat:externalEditor in ~/.claude/keybindings.json), as if still typing there.
#
# Zsh's edit-command-line passes `-c 'normal! {offset}go'`, the offset being the byte just after the cursor. Normal mode
# can't put the cursor past the end of a line, so when that byte is the line's newline, `go` stops one character short,
# and insert mode has to append instead.
#
# Claude Code passes `+{line}`, the cursor's line but not its column, so insert at the end of that line, where the
# cursor most often is.

def InsertAtCursor()
  for arg in v:argv
    const offset = matchstr(arg, '^normal! \zs\d\+\zego$')
    if offset != ''
      const reached = line2byte(line('.')) + col('.') - 1  # The byte the cursor is on after `go`
      if reached < str2nr(offset)
        startinsert!
      else
        startinsert
      endif
      return
    endif
  endfor
  if expand('%:t') =~# '^claude-prompt-.*\.md$'
    startinsert!
  endif
enddef

augroup insertatcursor
  autocmd!
  autocmd VimEnter * InsertAtCursor()
augroup END
