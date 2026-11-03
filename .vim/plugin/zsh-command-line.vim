vim9script
# Colour a zsh command line being edited in Vim (after cmd+e, see edit-command-line-highlighted in .zshrc) exactly as
# zsh colours it on the command line. Zsh gives Vim its context file (its aliases, function names and options, which
# decide the colours) in $ZSH_HIGHLIGHT_CONTEXT, and Vim keeps ~/.zsh/highlight-commands.zsh running with it for the
# whole edit, asking it for the colours after each change. These are laid over the text as text properties, replacing
# Vim's own zsh syntax colours (which still show if the highlighter can't run).
#
# As zsh does, Vim waits for the colours before redrawing (~8ms for a typical command line), so they're never a
# keystroke behind. If they ever take longer than 50ms, it stops waiting so that typing doesn't stutter, and applies
# them when they arrive instead.

if empty($ZSH_HIGHLIGHT_CONTEXT) || !has('textprop') || !has('job')
  finish
endif
const context = $ZSH_HIGHLIGHT_CONTEXT
# Hide it from programs run from Vim (e.g. another Vim, which would otherwise colour its own file this way).
unlet $ZSH_HIGHLIGHT_CONTEXT

var channel: channel
var bufnr = 0
var pending = false  # Whether the highlighter's reply to the last request is yet to be read
var sent_tick = 0  # The buffer's changedtick when the last request was sent
var sent_lines = 0  # The number of lines sent in the last request
var types: dict<string> = {}  # The text property type for each zle highlight spec

def Start()
  bufnr = bufnr()
  const job = job_start(
    ['zsh', '-f', expand('~/.zsh/highlight-commands.zsh'), '--ranges', context],
    # A reply that ch_read() in Request() gave up waiting for comes here instead (Vim drops it if there's no callback).
    {mode: 'nl', err_io: 'null', out_cb: (_, reply) => Receive(reply)}
  )
  if job_status(job) != 'run'
    return
  endif
  channel = job_getchannel(job)
  augroup zshcommandline
    autocmd!
    autocmd TextChanged,TextChangedI,TextChangedP <buffer> Changed()
  augroup END
  Request(1000)  # Waits longer, as the highlighter takes ~40ms to start.
enddef

def Changed()
  # If the last reply is late, the colours are asked for again once it arrives.
  if !pending
    Request(50)
  endif
enddef

# Send the buffer to the highlighter, and apply the colours in its reply if it arrives within `timeout` milliseconds
# (otherwise once it does).
def Request(timeout: number)
  if ch_status(channel) != 'open'
    return
  endif
  const lines = getbufline(bufnr, 1, '$')
  sent_tick = getbufvar(bufnr, 'changedtick')
  sent_lines = len(lines)
  ch_sendraw(channel, $"{len(lines)}\n" .. join(lines, "\n") .. "\n")
  pending = true
  const reply = ch_read(channel, {timeout: timeout})
  if reply != ''  # Otherwise it's late, and goes to Receive() via the channel's callback when it arrives.
    Receive(reply)
  endif
enddef

# Handle a reply from the highlighter.
def Receive(reply: string)
  pending = false
  if getbufvar(bufnr, 'changedtick') == sent_tick
    Apply(reply)
  else
    Request(50)  # The text changed while waiting, so the colours are out of date.
  endif
enddef

# Colour the buffer as given by a reply from the highlighter (see highlight-commands.zsh for its format).
def Apply(reply: string)
  const ranges = split(reply)
  if empty(ranges) || str2nr(ranges[0]) != sent_lines
    return
  endif
  prop_clear(1, sent_lines, {bufnr: bufnr})
  var positions: dict<list<list<number>>> = {}  # The positions to colour, for each text property type
  var lnum = 0
  var text = ''
  for range in ranges[1 :]
    const fields = split(range, ':', true)
    const row = str2nr(fields[0])
    if row != lnum
      lnum = row
      text = getbufline(bufnr, lnum)[0]
    endif
    # The highlighter counts characters (code points, so composing characters separately), where Vim counts bytes.
    const start = byteidxcomp(text, str2nr(fields[1]))
    const end = byteidxcomp(text, str2nr(fields[2]))
    if start < 0 || end < 0
      continue
    endif
    const type = Type(join(fields[3 :], ':'))
    if !has_key(positions, type)
      positions[type] = []
    endif
    positions[type]->add([lnum, start + 1, lnum, end + 1])
  endfor
  for [type, list] in items(positions)
    prop_add_list({type: type, bufnr: bufnr}, list)
  endfor
enddef

# Return the text property type for a zle highlight spec (e.g. `fg=#cba6f7,italic`), creating it the first time.
def Type(spec: string): string
  if !has_key(types, spec)
    const name = $'ZshCommandLine{len(types)}'
    var attributes: list<string> = []
    var colours: list<string> = []
    for part in split(spec, ',')
      const key = part[: 1]
      const colour = part[3 :]
      if (key == 'fg' || key == 'bg') && part[2] == '=' && colour != 'default'
        # Colours are `#rrggbb`, a name or a number (0-255). termguicolors is on, so numbers only apply without it.
        if colour =~ '^\d\+$'
          colours->add($'cterm{key}={colour}')
        else
          colours->add($'gui{key}={colour}')
          if colour !~ '^#'
            colours->add($'cterm{key}={colour}')
          endif
        endif
      elseif index(['bold', 'italic', 'underline', 'standout'], part) >= 0
        attributes->add(part)
      endif
    endfor
    const attribute = empty(attributes) ? 'NONE' : join(attributes, ',')
    execute $'highlight {name} gui={attribute} cterm={attribute} {join(colours)}'
    # Not combined with the syntax colours, so these are the only ones shown.
    prop_type_add(name, {highlight: name, combine: false})
    types[spec] = name
  endif
  return types[spec]
enddef

augroup zshcommandline
  autocmd!
  autocmd VimEnter * Start()
augroup END
