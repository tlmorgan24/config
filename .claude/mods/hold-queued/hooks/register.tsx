import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Editing, Held } from '../types'

// Hold a message sent with `chat:queueSubmit` (bound to Cmd+Enter) while Claude is working until its turn ends. Claude
// Code marks such a message with `wait` but still hands it to Claude mid-turn, so take it here instead and submit it
// once the turn is over, one held message per turn, in the order they were sent. The held messages are listed above
// the prompt box until they are sent.
//
// Option+Up takes back the newest held message for editing, and further presses step to older ones (Option+Down to
// newer ones, and past the newest back to the draft). While one is taken back, Enter and Cmd+Enter both put the box's
// text back in its place, or delete it from the queue if the box is empty, Option+C cancels the editing (undoing every
// edit since the first Option+Up), and no held message is submitted until then. The keys reach the mod through the
// list's buttons, which name otherwise unused Claude Code actions that keybindings.json binds to these keys.

const held = atom({ plugin: 'hold-queued', key: 'held' } as const, [] as Held)
const editing = atom({ plugin: 'hold-queued', key: 'editing' } as const, null as Editing)

const ZWSP = '\u200b'  // Kept in the box while it would otherwise be empty, so Enter still submits (and is seen)

let draft = ''  // What the box held before the first Option+Up, put back once editing ends
let original: Held = []  // The held messages before the first Option+Up, put back if the editing is cancelled
let submits = 0  // Count of submissions, to tell an empty submit (no submission follows its clear) from a real one
let isTurnRunning = false
let isReleaseDue = false  // A turn ended while a message was being edited, so the next one is due once editing ends
let pending: { text: string; replacement: string } | null = null  // A dropped message, and what replaces it in the box

const strip = (text: string) => text.replaceAll(ZWSP, '')

// Put messages back in the prompt box (after anything already typed there), for when they can't be submitted.
async function putBack($: EngineInterface, texts: string[]) {
  const box = await $.prompt.read()
  await $.prompt.fill({ text: [strip(box.text), ...texts].filter(text => text.trim() !== '').join('\n\n') })
  $.ui.toast(
    texts.length === 1
      ? 'Held message put back in the prompt box'
      : `${texts.length} held messages put back in the prompt box, merged into one`,
  )
}

// Submit the oldest held message, putting it back in the prompt box if Claude Code refuses it.
async function sendNext($: EngineInterface) {
  const [text] = await read($, held)
  if (text === undefined) {
    return
  }
  await update($, held, list => list.slice(1))
  try {
    const result = await $.prompt.submit({ text, asUser: true })
    if (result.drop !== undefined) {
      await putBack($, [text])
    }
  } catch {
    await putBack($, [text])
  }
}

// Submit the next held message if a turn ended while one was being edited (and no turn has started since).
async function releaseIfDue($: EngineInterface) {
  if (isReleaseDue && !isTurnRunning) {
    isReleaseDue = false
    await sendNext($)
  }
}

// Show a held message in the prompt box for editing.
async function show($: EngineInterface, text: string) {
  await $.prompt.fill({ text: text === '' ? ZWSP : text })
}

// Keep the box's edits to the message being edited, unless the box has been emptied.
async function keepEdits($: EngineInterface, index: number) {
  const text = strip((await $.prompt.read()).text)
  if (text.trim() !== '') {
    await update($, held, list => list.map((old, i) => (i === index ? text : old)))
  }
}

// Claude Code puts a dropped message back in the prompt box, so replace it the moment it does (see the
// `prompt.change` hook), or shortly after if that is missed (unless the box has been edited since).
function replaceWhenPutBack($: EngineInterface, text: string, replacement: string) {
  pending = { text, replacement }
  $.clock.after(300, async () => {
    if (pending?.text === text) {
      pending = null
      if (strip((await $.prompt.read()).text).trim() === text.trim()) {
        await $.prompt.fill({ text: replacement })
      }
    }
  })
}

// End editing, putting the draft from before it back in the box (in place of `dropped`, the text a submit dropped,
// once Claude Code has put that back).
async function stopEditing($: EngineInterface, dropped?: string) {
  await update($, editing, () => null)
  if (dropped === undefined) {
    await $.prompt.fill({ text: draft })
  } else {
    replaceWhenPutBack($, dropped, draft)
  }
  $.clock.after(0, () => releaseIfDue($))  // Submitting from inside a `prompt.submit` hook is refused, so do it after.
}

// Option+Up: take back the newest held message, or step to the one before the message being edited.
async function editOlder($: EngineInterface) {
  const list = await read($, held)
  const index = await read($, editing)
  if (list.length === 0) {
    return
  }
  if (index === null) {
    draft = strip((await $.prompt.read()).text)
    original = list
  } else {
    await keepEdits($, index)
  }
  const target = index === null ? list.length - 1 : Math.max(index - 1, 0)
  await update($, editing, () => target)
  await show($, (await read($, held))[target] ?? '')
}

// Option+Down: step to the message after the one being edited, or past the newest back to the draft.
async function editNewer($: EngineInterface) {
  const index = await read($, editing)
  if (index === null) {
    return
  }
  await keepEdits($, index)
  const list = await read($, held)
  if (index + 1 >= list.length) {
    await stopEditing($)
  } else {
    await update($, editing, () => index + 1)
    await show($, list[index + 1] ?? '')
  }
}

// Option+C: cancel the editing, undoing every edit since the first Option+Up and putting the draft back in the box.
async function cancelEditing($: EngineInterface) {
  if ((await read($, editing)) === null) {
    return
  }
  const messages = original
  await update($, held, () => messages)
  await stopEditing($)
}

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    submits += 1
    const index = await read($, editing)
    if (index !== null && e.command === undefined) {
      // Put the box's text back in the place of the message being edited.
      await update($, held, list => list.map((old, i) => (i === index ? e.text : old)))
      await stopEditing($, e.text)

      return { drop: 'Put back in its place.' }
    }
    if (!e.wait || e.turnId === undefined || e.command !== undefined) {
      return next(e)
    }
    await update($, held, list => [...list, e.text])
    replaceWhenPutBack($, e.text, '')

    return { drop: 'Held until Claude finishes.' }
  }).catch(($, e, next) => next(e))  // If the hook fails, send the message as normal rather than lose it.

  // Keep the box from going empty while a message is being edited.
  on('prompt.edit', async ($, e, next) => {
    const box = await next(e)
    if (box.text === '' && (await read($, editing)) !== null) {
      return { ...box, text: ZWSP, cursor: 1 }
    }

    return box
  })

  on('prompt.change', async ($, e, next) => {
    if (pending !== null && e.origin.kind === 'engine' && strip(e.text).trim() === pending.text.trim()) {
      const { replacement } = pending
      pending = null
      await $.prompt.fill({ text: replacement })

      return next(e)
    }
    const index = await read($, editing)
    if (index !== null && e.origin.kind === 'clear') {
      // Enter on an empty box clears it without submitting anything: delete the message being edited.
      const seen = submits
      $.clock.after(300, async () => {
        if (submits === seen && (await read($, editing)) === index) {
          await update($, held, list => list.filter((_, i) => i !== index))
          $.ui.toast('Held message deleted')
          await stopEditing($)
        }
      })
    } else if (index !== null && e.origin.kind !== 'plugin' && e.text === '') {
      await show($, '')  // E.g. an undo emptied the box.
    }

    return next(e)
  })

  on('turn.start', ($, e, next) => {
    if (e.agentId === undefined) {
      isTurnRunning = true
    }

    return next(e)
  })

  // When the main conversation's turn ends, submit the next held message, unless one is being edited. After an
  // interrupt (Esc), Claude Code refuses any message a mod submits until the person types again, so put all of them
  // back in the prompt box instead.
  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      isTurnRunning = false
      const list = await read($, held)
      if ((await read($, editing)) !== null) {
        isReleaseDue = list.length > 0
      } else if (list.length > 0 && e.reason === 'aborted') {
        await update($, held, () => [])
        void putBack($, list)
      } else if (list.length > 0) {
        void sendNext($)
      }
    }

    return next(e)
  })

  // List the held messages above the prompt box, one line each, while there are any. The buttons carry the Option+Up,
  // Option+Down and (while editing) Option+C keys (see above).
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, held)
    if (list.length === 0 || e.props.hasSurvey) {
      return next(e)
    }
    const index = await read($, editing)
    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column" width={e.props.bodyColumns}>
        <Box>
          <Text dimColor>Held until Claude finishes ({list.length}) · edit </Text>
          <Button
            key="older"
            label="⌥↑"
            plain
            dimColor
            action="app:toggleDiffNoiseFilter"
            onPress={() => editOlder($)}
          />
          <Text dimColor> </Text>
          <Button
            key="newer"
            label="⌥↓"
            plain
            dimColor
            action="app:toggleDiffPreSession"
            onPress={() => editNewer($)}
          />
          {index !== null && <Text dimColor> · cancel </Text>}
          {/* Not Option+.: the terminal sends Esc then `.`, which Claude Code takes as Esc, interrupting Claude. */}
          {index !== null && (
            <Button
              key="cancel"
              label="⌥C"
              plain
              dimColor
              action="app:toggleReplTab"
              onPress={() => cancelEditing($)}
            />
          )}
        </Box>
        {list.map((text, i) => (
          <Text key={`${i}`} wrap="truncate-end" bold={i === index}>
            {i === index ? '▸ ' : '  '}{i + 1}. {text.replace(/\s*\n\s*/g, ' ⏎ ')}{i === index ? ' (editing)' : ''}
          </Text>
        ))}
      </Box>
    )
  })
}
