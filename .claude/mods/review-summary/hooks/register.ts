import type { EngineInterface, Register } from 'claude-code'

// Show the summary of a `/review` (written by `~/.claude/review/review.sh`) in the transcript as soon as it appears, as
// a notice the model never reads, so it reaches me without going through the writer (this session's Claude).
//
// Check before each of the model's steps, so the summary is shown before the writer reads the notification that the
// review has finished, and at the end of each turn.

let path: string | undefined
let shown: string | undefined  // The summary last shown, so it isn't shown again

async function read($: EngineInterface): Promise<string | undefined> {
  path ??= `${await $.env.get('HOME')}/.cache/claude-review/${await $.session.id()}/summary.md`

  return $.fs.read(path).catch(() => undefined)
}

async function check($: EngineInterface): Promise<void> {
  const summary = await read($)
  // `review.sh start` deletes the last summary, so forget it then, and a new review's is shown even if it's the same.
  if (summary === undefined || summary === shown) {
    shown = summary
    return
  }
  shown = summary
  await $.session.append({ message: { type: 'system', content: [{ type: 'text', text: summary.trimEnd() }] } })
}

function logError($: EngineInterface, error: unknown): void {
  $.ui.log(`review-summary: couldn't show the review summary: ${String(error)}`)
}

export const register: Register = on => {
  // Don't show again a summary that was there before this session (or reload of the mod) started, e.g. on resuming.
  on('session.start', async ($, e, next) => {
    shown = await read($).catch(() => undefined)

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
}
