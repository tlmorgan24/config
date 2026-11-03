import type { EngineInterface, PromptDecoration, Register, UiCopyArgs } from 'claude-code'

// Select text in the prompt box like in a GUI text editor (and my zsh). Shift with any cursor move (arrows,
// Option+arrows, Cmd+arrows) selects from where the cursor was, and a move without Shift drops the selection
// (Left/Right collapsing it to its left/right edge). Typing, pasting, Backspace and Delete replace the selection. Cmd+X
// cuts the selection and Cmd+Shift+C copies it (or, with nothing selected in the prompt box, what is selected with the
// mouse). Cmd+Up/Down move to the start/end of the whole prompt, and Cmd+Shift+Up/Down select to there (the cursor
// staying at the far end for Cmd+Shift+Up, see `moveToEdge`).
//
// Cmd+X, Cmd+Shift+C and Cmd+(Shift+)Up/Down reach the mod through hidden buttons naming otherwise unused Claude Code
// actions that keybindings.json binds to them, which also keeps Cmd+X and Cmd+Shift+C from typing a letter when there
// is nothing to cut or copy.

const NAME = 'prompt-select'

const SELECTED_BACKGROUND = '#585b70'  // Catppuccin Mocha surface2

// Backspace at the very start of the box deletes nothing, so Claude Code raises no edit for it. While a leftward
// selection reaches the start, the box therefore starts with this invisible pad, giving Backspace something to delete
// (and the mod an edit to see). The pad goes as soon as the selection no longer reaches the start.
//
// Likewise, Right or Delete at the very end raises no edit, so while a rightward selection reaches the end, the box
// ends with `TAIL`. A fill drops the zero-width pad, so the tail is a no-break space instead, invisible at the end.
const PAD = '​'
const TAIL = '\u00a0'

type Surface = UiCopyArgs['surface']

let anchor: number | null = null  // Where the selection started (pad included), the cursor being its other end
let isPadded = false  // Whether the box starts with `PAD`
let isTailed = false  // Whether the box ends with `TAIL`
let lastCursor: number | null = null  // Where the cursor was when the mod last saw it
let isPainted = false  // Whether `moveToEdge` painted a selection with `$.prompt.paint`

// Clear what `moveToEdge` painted. Unlike the decorations an edit answers with, a paint stays through later edits while
// any plugin hooks them, so it would otherwise keep showing a selection that has since changed or gone.
async function clearPaint($: EngineInterface) {
  if (isPainted) {
    isPainted = false
    await $.prompt.paint({ decorations: [] })
  }
}

// Note where the cursor ends up after an edit.
function seen<T extends { cursor: number }>(box: T): T {
  lastCursor = box.cursor

  return box
}

// Drop the tail from `box` if it still ends with it and `wasTailed`, keeping the cursor before it.
function untail<T extends { text: string; cursor: number }>(box: T, wasTailed: boolean): T {
  if (!wasTailed || !box.text.endsWith(TAIL)) {
    return box
  }
  const text = box.text.slice(0, -TAIL.length)

  return { ...box, text, cursor: Math.min(box.cursor, text.length) }
}

// Whether the selection runs rightward to the end of `text`, needing the tail.
const needsTail = (text: string, cursor: number) => anchor !== null && anchor < cursor && cursor === text.length

const range = (cursor: number): [number, number] =>
  anchor === null ? [cursor, cursor] : [Math.min(anchor, cursor), Math.max(anchor, cursor)]

// Find where removing the selection [start, end) should start from, the pad going with a selection right after it.
const removalStart = (text: string, start: number, isPadPresent: boolean) =>
  isPadPresent && start === 1 && text.startsWith(PAD) ? 0 : start

// Count the characters `text` holds as the person sees them (e.g. an emoji is one).
function countCharacters(text: string): number {
  try {
    return [...new Intl.Segmenter().segment(text)].length
  } catch {
    return [...text].length
  }
}

// Cmd+Left/Right reach Claude Code as Ctrl+A/E (Ghostty's defaults), moving to the start/end of the line between
// newlines, but Cmd+Shift+Left/Right reach it as themselves, moving to the start/end of the line as wrapped on screen.
// Make the latter match the former (as in my zsh). The mod sees Cmd+Shift+Left as plain Shift+Left, so tell them apart
// by the distance moved, as Shift+Left only ever moves one character.
function toLineEdge(text: string, from: number, to: number, key: string | undefined): number {
  const moved = countCharacters(text.slice(Math.min(from, to), Math.max(from, to)))
  if ((key !== 'left' && key !== 'right') || moved <= 1) {
    return to
  }
  if (key === 'left') {
    return text.lastIndexOf('\n', from - 1) + 1
  }
  const end = text.indexOf('\n', from)

  return end === -1 ? text.length : end
}

// Paint the selection. Claude Code never paints the character under the cursor, so a leftward selection's first
// character shows unpainted.
function paint(cursor: number): PromptDecoration[] {
  const [start, end] = range(cursor)

  return start === end ? [] : [{ start, end, backgroundColor: SELECTED_BACKGROUND }]
}

// Put `text` on the clipboard, saying so if that fails.
async function copy($: EngineInterface, text: string, surface: Surface): Promise<boolean> {
  const copied = await $.ui.copy({ text, surface })
  if (!copied.isCopied) {
    $.ui.toast(`Could not copy the selection (${copied.reason})`)
  }

  return copied.isCopied
}

// Cmd+X: cut the selection to the clipboard.
async function cut($: EngineInterface, surface: Surface) {
  const box = await $.prompt.read()
  const [start, end] = range(box.cursor)
  if (start < end && (await copy($, box.text.slice(start, end), surface))) {
    const from = removalStart(box.text, start, isPadded)
    const rest = untail({ text: box.text.slice(end), cursor: 0 }, isTailed).text
    anchor = null
    isPadded = false
    isTailed = false
    await clearPaint($)
    await $.prompt.fill({ text: box.text.slice(0, from) + rest, cursor: from })
  }
}

// Cmd+Shift+C: copy the selection, or else what is selected with the mouse.
async function copySelection($: EngineInterface, surface: Surface) {
  const box = await $.prompt.read()
  const [start, end] = range(box.cursor)
  const text = start < end ? box.text.slice(start, end) : ((await $.ui.selection())?.text ?? '')
  if (text !== '') {
    await copy($, text, surface)
  }
}

// Cmd+Up/Down: move to the start/end of the whole prompt, or with Shift, select to there. A fill can't add the pad, so
// Cmd+Shift+Up instead selects from the start with the cursor left at the selection's far end, where Backspace still
// raises an edit.
async function moveToEdge($: EngineInterface, isEnd: boolean, isSelecting: boolean) {
  const box = await $.prompt.read()
  const shift = isPadded && box.text.startsWith(PAD) ? 1 : 0
  const wasTailed = isTailed && box.text.endsWith(TAIL)
  const text = untail(box, wasTailed).text.slice(shift)
  // Where the selection reaches from (Shift) or the cursor was
  const from = Math.min((anchor ?? box.cursor) - shift, text.length)
  let cursor = isEnd ? text.length : 0
  anchor = isSelecting ? from : null
  if (isSelecting && !isEnd) {
    cursor = from
    anchor = from > 0 ? 0 : null
  }
  const isTailing = needsTail(text, cursor)
  isPadded = false
  let filled
  if (shift === 1 || (wasTailed && !isTailing)) {
    filled = await $.prompt.fill({ text: text + (isTailing ? TAIL : ''), cursor })  // A fill drops the pad.
  } else if (isTailing && !wasTailed) {
    filled = await $.prompt.fill({ text: TAIL, mode: 'append', cursor })
  } else {
    filled = await $.prompt.fill({ text: '', mode: 'insert', cursor })
  }
  isTailed = isTailing && filled.text.endsWith(TAIL)
  lastCursor = cursor
  await clearPaint($)
  const decorations = paint(cursor)
  if (decorations.length > 0) {
    isPainted = (await $.prompt.paint({ text: filled.text, decorations })).isPainted
  }
}

export const register: Register = on => {
  on('prompt.edit', async ($, e, next) => {
    const k = e.key
    await clearPaint($)
    const wasPadded = isPadded && e.text.startsWith(PAD)
    const wasTailed = isTailed && e.text.endsWith(TAIL)
    isPadded = false
    isTailed = false
    const done = <T extends { text: string; cursor: number }>(box: T): T => seen(untail(box, wasTailed))
    // Drop the selection if the cursor moved without the mod seeing (e.g. a click), as it would otherwise reach
    // somewhere the person never saw highlighted.
    if (lastCursor !== null && e.cursor !== lastCursor) {
      anchor = null
    }

    // Make Cmd+Backspace (Ctrl+U from Ghostty) delete back to the start of the line between newlines, as in my zsh
    // (whether or not there is a selection), rather than to the start of the line as wrapped on screen.
    if (k?.ctrl === true && k.key === 'u') {
      anchor = null
      const lineStart = e.text.lastIndexOf('\n', e.cursor - 1) + 1
      if (lineStart === e.cursor) {
        return done({ text: e.text, cursor: e.cursor })
      }

      return done(await next({ ...e, start: lineStart, end: e.cursor }))
    }

    // Make typing, pasting, Backspace or Delete at the cursor replace the selection, if there is one. Other deletions
    // (Option+Backspace, Ctrl+W, ...) ignore the selection, as in my zsh. Keys that arrive together (e.g. a held
    // Backspace repeating) come as one edit without `key`.
    if (e.inputText !== '' || e.start !== e.end) {
      const [start, end] = range(e.cursor)
      anchor = null
      const isPlainDelete = (k?.key === 'backspace' || k?.key === 'delete') && k.meta !== true && k.ctrl !== true
      const isReplacing = e.inputText !== '' || isPlainDelete || k === undefined
      if (isReplacing && start < end && e.start <= e.cursor && e.cursor <= e.end) {
        return done(await next({ ...e, start: removalStart(e.text, start, wasPadded), end }))
      }
      const r = await next(e)
      if (wasPadded && r.text.startsWith(PAD)) {
        return done({ ...r, text: r.text.slice(1), cursor: Math.max(r.cursor - 1, 0) })
      }

      return done(r)
    }

    // For a cursor move, drop the pad and tail (if any), then select from where the cursor was if Shift is held. Keys
    // that arrive together (e.g. a held Shift+Left repeating) come as one edit without `key`, so keep selecting through
    // those.
    const r = await next(e)
    if (r.text !== e.text) {
      anchor = null

      return done(r)
    }
    const shift = wasPadded ? 1 : 0
    const moved = untail(r, wasTailed)
    let text = moved.text.slice(shift)
    const isShiftOnly = k?.shift === true && k.meta !== true && k.ctrl !== true
    let cursor = isShiftOnly ? toLineEdge(moved.text, e.cursor, r.cursor, k.key) : r.cursor
    cursor = Math.min(Math.max(cursor - shift, 0), text.length)
    const isSelecting = k?.shift === true || (k === undefined && anchor !== null)
    const isCollapsing = (k?.key === 'left' || k?.key === 'right') && !k.shift && !k.meta && !k.ctrl && anchor !== null
    if (isCollapsing) {
      // Left/Right with a selection: collapse it to its left/right edge (as in my zsh), rather than moving on from the
      // cursor.
      const [start, end] = range(e.cursor)
      cursor = (k.key === 'left' ? start : end) - shift
    }
    anchor = isSelecting ? (anchor ?? e.cursor) - shift : null
    if (anchor !== null && anchor > 0 && cursor === 0) {
      text = PAD + text
      cursor = 1
      anchor += 1
      isPadded = true
    }
    if (needsTail(text, cursor)) {
      text += TAIL
      isTailed = true
    }
    const offset = (isPadded ? 1 : 0) - shift  // How far the box's text moved, for other plugins' decorations
    const others = (r.decorations ?? []).map(d => ({ ...d, start: d.start + offset, end: d.end + offset }))

    return seen({ ...r, text, cursor, decorations: [...others, ...paint(cursor)] })
  })

  // Drop the selection when the box changes some other way (history, a clear, a submit, another plugin's fill), but not
  // for this mod's own fills. An undo can bring back a text with the pad or tail, so treat it as padded or tailed,
  // which drops them at the next key (or submit).
  on('prompt.change', async ($, e, next) => {
    lastCursor = e.cursor
    if (e.origin.kind !== 'plugin' || e.origin.name !== NAME) {
      anchor = null
      isPadded = e.origin.kind === 'undo' && e.text.startsWith(PAD)
      isTailed = e.origin.kind === 'undo' && e.text.endsWith(TAIL)
      await clearPaint($)
    }

    return next(e)
  })

  // Never send the pad or tail to Claude.
  on('prompt.submit', (_$, e, next) => {
    let text = e.text
    if (isPadded && text.startsWith(PAD)) {
      text = text.slice(PAD.length)
    }
    if (isTailed && text.endsWith(TAIL)) {
      text = text.slice(0, -TAIL.length)
    }
    isPadded = false
    isTailed = false

    return text === e.text ? next(e) : next({ ...e, text })
  })

  // Mount the (hidden) buttons carrying the keys, after whatever else is drawn above the prompt box.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props.hasSurvey) {
      return below
    }
    const { Box, Button } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {below}
        <Box display="none">
          <Button key="cut" label="Cut" action="app:cycleDiffBase" onPress={press => cut($, press.surface)} />
          <Button key="copy" label="Copy" action="strip:jump9" onPress={press => copySelection($, press.surface)} />
          <Button key="top" label="Top" action="strip:jump1" onPress={() => moveToEdge($, false, false)} />
          <Button key="bottom" label="Bottom" action="strip:jump2" onPress={() => moveToEdge($, true, false)} />
          <Button key="selectTop" label="Select top" action="strip:jump5" onPress={() => moveToEdge($, false, true)} />
          <Button
            key="selectBottom"
            label="Select bottom"
            action="strip:jump6"
            onPress={() => moveToEdge($, true, true)}
          />
        </Box>
      </Box>
    )
  })
}
