import type { EngineInterface, PromptDecoration, Register, UiCopyArgs } from 'claude-code'

// Select text in the prompt box like in a GUI text editor (and my zsh). Shift with any cursor move (arrows,
// Option+arrows, Cmd+arrows) selects from where the cursor was, and a move without Shift drops the selection. Typing or
// pasting replaces the selection, and a deletion (Backspace, Delete, Ctrl+W, ...) deletes it. Cmd+X cuts the selection
// and Cmd+Shift+C copies it (or, with nothing selected in the prompt box, what is selected with the mouse).
//
// The keys reach the mod through hidden buttons naming otherwise unused Claude Code actions that keybindings.json binds
// to them, which also keeps them from typing a letter when there is nothing to cut or copy.

const SELECTED_BACKGROUND = '#585b70'  // Catppuccin Mocha surface2

// Backspace at the very start of the box deletes nothing, so Claude Code raises no edit for it. While a leftward
// selection reaches the start, the box therefore starts with this invisible pad, giving Backspace something to delete
// (and the mod an edit to see). The pad goes as soon as the selection no longer reaches the start.
//
// Delete at the very end raises no edit either, and the box takes the Delete key before any keybinding, so that case is
// not handled.
const PAD = '​'

type Surface = UiCopyArgs['surface']

let anchor: number | null = null  // Where the selection started (pad included), the cursor being its other end
let isPadded = false  // Whether the box starts with `PAD`

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
    anchor = null
    isPadded = false
    await $.prompt.fill({ text: box.text.slice(0, from) + box.text.slice(end), cursor: from })
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

export const register: Register = on => {
  on('prompt.edit', async ($, e, next) => {
    const k = e.key
    const wasPadded = isPadded && e.text.startsWith(PAD)
    isPadded = false

    // Make Cmd+Backspace (Ctrl+U from Ghostty) delete back to the start of the line between newlines, as in my zsh
    // (whether or not there is a selection), rather than to the start of the line as wrapped on screen.
    if (k?.ctrl === true && k.key === 'u') {
      anchor = null
      const lineStart = e.text.lastIndexOf('\n', e.cursor - 1) + 1
      if (lineStart === e.cursor) {
        return { text: e.text, cursor: e.cursor }
      }

      return next({ ...e, start: lineStart, end: e.cursor })
    }

    // Make an edit at the cursor replace the selection, if there is one.
    if (e.inputText !== '' || e.start !== e.end) {
      const [start, end] = range(e.cursor)
      anchor = null
      if (start < end && e.start <= e.cursor && e.cursor <= e.end) {
        return next({ ...e, start: removalStart(e.text, start, wasPadded), end })
      }

      return next(e)
    }

    // For a cursor move, drop the pad (if any), then select from where the cursor was if Shift is held. Keys that
    // arrive together (e.g. a held Shift+Left repeating) come as one edit without `key`, so keep selecting through
    // those.
    const r = await next(e)
    if (r.text !== e.text) {
      anchor = null

      return r
    }
    const shift = wasPadded ? 1 : 0
    let text = r.text.slice(shift)
    const isShiftOnly = k?.shift === true && k.meta !== true && k.ctrl !== true
    let cursor = Math.max((isShiftOnly ? toLineEdge(r.text, e.cursor, r.cursor, k.key) : r.cursor) - shift, 0)
    const isSelecting = k?.shift === true || (k === undefined && anchor !== null)
    anchor = isSelecting ? (anchor ?? e.cursor) - shift : null
    if (anchor !== null && anchor > 0 && cursor === 0) {
      text = PAD + text
      cursor = 1
      anchor += 1
      isPadded = true
    }
    const offset = (isPadded ? 1 : 0) - shift  // How far the box's text moved, for other plugins' decorations
    const others = (r.decorations ?? []).map(d => ({ ...d, start: d.start + offset, end: d.end + offset }))

    return { ...r, text, cursor, decorations: [...others, ...paint(cursor)] }
  })

  // Drop the selection when the box changes some other way (history, a clear, a submit, a fill).
  on('prompt.change', (_$, e, next) => {
    anchor = null
    isPadded = false

    return next(e)
  })

  // Never send the pad to Claude.
  on('prompt.submit', (_$, e, next) => {
    if (isPadded && e.text.startsWith(PAD)) {
      isPadded = false

      return next({ ...e, text: e.text.slice(PAD.length) })
    }

    return next(e)
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
        </Box>
      </Box>
    )
  })
}
