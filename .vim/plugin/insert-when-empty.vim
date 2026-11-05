vim9script
# Start in insert mode in an empty buffer (a new or empty file, plain `vim`, or cmd+e on an empty zsh command line or
# Claude Code prompt), as there's nothing to do but type, unless it's read-only or in diff mode. Cmd+e on a non-empty
# command line or prompt starts in normal mode, ready for e.g. `ci"`.
#
# A git message (`git commit`, merge, tag) is empty too if all it has is git's `#` comments, which git strips, so start
# in insert mode at the top there. Lines from the scissors line on (the diff shown by `git commit -v`) don't count.

def CommentsOnly(): bool
  const scissors = search('^# -\+ >8 -\+$', 'nw')
  const lines = getline(1, scissors > 0 ? scissors - 1 : '$')
  return lines->indexof((_, l) => l !~ '^\s*$' && l !~ '^#') == -1
enddef

def InsertIfEmpty()
  if line('$') == 1 && getline(1) == '' && &modifiable && !&readonly && !&diff
    startinsert
  elseif &filetype == 'gitcommit' && CommentsOnly()
    cursor(1, 1)
    startinsert
  endif
enddef

augroup insertifempty
  autocmd!
  autocmd VimEnter * InsertIfEmpty()
augroup END
