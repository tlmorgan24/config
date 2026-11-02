import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

// Hold a message sent with `chat:queueSubmit` (bound to Cmd+Enter) while Claude is working until its turn ends. Claude
// Code marks such a message with `wait` but still hands it to Claude mid-turn, so take it here instead and submit it
// once the turn is over, one held message per turn, in the order they were sent. The held messages are listed above
// the prompt box until they are sent.

const held = atom({ plugin: 'hold-queued', key: 'held' } as const, [])  // Messages waiting to be submitted, oldest first

// Put messages back in the prompt box (after anything already typed there), for when they can't be submitted.
async function putBack($: EngineInterface, texts: string[]) {
  const box = await $.prompt.read()
  await $.prompt.fill({ text: [box.text, ...texts].filter(text => text.trim() !== '').join('\n\n') })
  $.ui.toast('Held message put back in the prompt box')
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

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    if (!e.wait || e.turnId === undefined || e.command !== undefined) {
      return next(e)
    }
    await update($, held, list => [...list, e.text])

    // Claude Code puts a dropped message back in the prompt box, so empty the box again once it has (unless it has
    // been edited since).
    $.clock.after(100, async () => {
      const box = await $.prompt.read()
      if (box.text.trim() === e.text.trim()) {
        await $.prompt.fill({ text: '' })
      }
    })

    return { drop: 'Held until Claude finishes.' }
  }).catch(($, e, next) => next(e))  // If the hook fails, send the message as normal rather than lose it.

  // When the main conversation's turn ends, submit the next held message. After an interrupt (Esc), Claude Code
  // refuses any message a mod submits until the person types again, so put all of them back in the prompt box instead.
  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      const list = await read($, held)
      if (list.length > 0 && e.reason === 'aborted') {
        await update($, held, () => [])
        void putBack($, list)
      } else if (list.length > 0) {
        void sendNext($)
      }
    }

    return next(e)
  })

  // List the held messages above the prompt box, one line each, while there are any.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, held)
    if (list.length === 0 || e.props.hasSurvey) {
      return next(e)
    }
    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column" width={e.props.bodyColumns}>
        <Text dimColor>Held until Claude finishes ({list.length}):</Text>
        {list.map((text, i) => (
          <Text key={`${i}`} wrap="truncate-end">
            {i + 1}. {text.replace(/\s*\n\s*/g, ' ⏎ ')}
          </Text>
        ))}
      </Box>
    )
  })
}
