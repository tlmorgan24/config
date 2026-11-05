import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Cards } from '../types'

// Show the summary of a `/review` (written by `~/.claude/review/review.sh`) in the transcript as soon as it appears, as
// a card under the row of the `review.sh` call that finished the review. Only the drawing changes, so the model never
// reads it, and the summary reaches me without going through the writer (this session's Claude).
//
// Check before each of the model's steps, so the summary is shown before the writer reads the notification that the
// review has finished, and at the end of each turn.

const REVIEW_CALL = /review\.sh\s+(start|respond)\b/

// Keep these in the session's state, not module variables, so that they survive a reload of the mod.
const lastCall = atom({ plugin: 'review-summary', key: 'lastCall' } as const, null)  // The last `review.sh` call's id
const cards = atom({ plugin: 'review-summary', key: 'cards' } as const, {})  // Each summary by its call's id

let path: string | undefined
let shown: string | undefined  // The summary last shown, so it isn't shown again

async function readSummary($: EngineInterface): Promise<string | undefined> {
  path ??= `${await $.env.get('HOME')}/.cache/claude-review/${await $.session.id()}/summary.md`

  return $.fs.read(path).catch(() => undefined)
}

async function check($: EngineInterface): Promise<void> {
  const summary = await readSummary($)
  // `review.sh start` deletes the last summary, so forget it then, and a new review's is shown even if it's the same.
  if (summary === undefined || summary === shown) {
    shown = summary
    return
  }
  shown = summary
  const call = await read($, lastCall)
  if (call === null) {
    // Not run by the model (e.g. run as `! review.sh ...`), so there's no row to put the card under.
    $.ui.log(summary.trimEnd())
    return
  }
  await update($, cards, (all: Cards): Cards => ({ ...all, [call]: summary.trimEnd() }))
}

function logError($: EngineInterface, error: unknown): void {
  $.ui.log(`review-summary: couldn't show the review summary: ${String(error)}`)
}

export const register: Register = on => {
  // Don't show again a summary that was there before this session (or reload of the mod) started, e.g. on resuming.
  on('session.start', async ($, e, next) => {
    shown = await readSummary($).catch(() => undefined)

    return next(e)
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (REVIEW_CALL.test(e.command)) {
      await update($, lastCall, () => e.tool_use_id).catch((error: unknown) => logError($, error))
    }

    return next(e)
  })

  // An async generator, as `turn.step` streams the model's answer.
  on('turn.step', async function* ($, e, next) {
    await check($).catch((error: unknown) => logError($, error))

    return yield* next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await check($).catch((error: unknown) => logError($, error))

    return next(e)
  })

  on('ui.render', { component: 'ToolUse' }, async ($, e, next) => {
    const summary = (await read($, cards))[e.props.tool_use_id]
    if (summary === undefined) {
      return next(e)
    }
    const { Box, Markdown } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {await next(e)}
        <Box borderStyle="round" paddingX={1}>
          <Markdown text={summary} />
        </Box>
      </Box>
    )
  })
}
