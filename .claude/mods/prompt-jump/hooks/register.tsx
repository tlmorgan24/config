import type { EngineInterface, Register, RenderInput } from 'claude-code'

// Ctrl+Up/Down: scroll the transcript so the previous/next prompt I sent sits at the top of the screen, as the terminal
// does between shell prompts. Ctrl+Up from partway through a turn goes to that turn's own prompt first. Only works
// where the terminal lets Ctrl+Up/Down through to Claude Code (see Terminal in the README).
//
// Claude Code only lays out the rows near the screen, so the mod can't learn the order of the prompts from what it
// sees. It instead reads that order from the session's transcript file, and finds where the screen is by the rows
// Claude Code reports on screen. The keys reach the mod through hidden buttons naming otherwise unused Claude Code
// actions that keybindings.json binds to them.

// The transcript's row ids, tool call ids and marks of a prompt I sent (typed, or released by my hold-queued mod)
const PATTERN = String.raw`"uuid":"[^"]+"|"id":"toolu_[^"]+"|"origin":\{"kind":"human"|"asUser":true`

// The transcript rows that report which of their rows are on screen and have their id in the transcript file
const TRACKED = /^(UserMessage|AssistantMessage|ToolUse|ToolResult|ToolGroup|TurnDuration)$/

const RESCROLL_DELAY_MS = 100

type Prompt = { line: number; id: string }
type Order = { lineOf: Map<string, number>; prompts: Prompt[] }

let transcriptPath: string | undefined
// Rows on screen by id, each with how many of its rows are scrolled off the top
const shown = new Map<string, number>()
let reports = 0  // Count of on-screen reports, to tell whether any arrived since the last jump
let lastJump: { id: string; reports: number } | undefined

// Read the transcript file's prompts in order, and the line of the transcript holding each row id.
async function readOrder($: EngineInterface): Promise<Order | undefined> {
  if (transcriptPath === undefined) {
    return undefined
  }
  const found = await $.process.run(['rg', '--no-config', '-no', '-e', PATTERN, transcriptPath]).catch(() => undefined)
  if (found === undefined || found.exitCode > 1) {
    return undefined
  }
  const lineOf = new Map<string, number>()
  const rowOf = new Map<number, string>()  // Each line's own row id
  const promptLines: number[] = []
  for (const entry of found.stdout.split('\n')) {
    const colon = entry.indexOf(':')
    const line = Number(entry.slice(0, colon))
    const match = entry.slice(colon + 1)
    if (match.startsWith('"origin"') || match.startsWith('"asUser"')) {
      promptLines.push(line)
    } else if (colon > 0) {
      const id = match.slice(match.indexOf(':') + 2, -1)
      if (!lineOf.has(id)) {
        lineOf.set(id, line)
      }
      if (match.startsWith('"uuid"') && !rowOf.has(line)) {
        rowOf.set(line, id)
      }
    }
  }
  const prompts = [...new Set(promptLines)].flatMap(line => {
    const id = rowOf.get(line)

    return id === undefined ? [] : [{ line, id }]
  })

  return { lineOf, prompts }
}

// Find the prompt to jump to: the one before/after the row at the top of the screen, or that row's own prompt if it is
// partly scrolled off. A press before Claude Code has reported where the last jump landed steps on from that jump.
function findTarget(order: Order, isDown: boolean): Prompt | undefined {
  const { prompts } = order
  if (lastJump?.reports === reports) {
    const index = prompts.findIndex(prompt => prompt.id === lastJump?.id)
    if (index !== -1) {
      return prompts[isDown ? index + 1 : index - 1]
    }
  }
  let top: { line: number; scrolledOff: number } | undefined
  for (const [id, scrolledOff] of shown) {
    const line = order.lineOf.get(id.replace(/^collapsed-/, ''))
    if (line !== undefined && (top === undefined || line < top.line)) {
      top = { line, scrolledOff }
    }
  }
  if (top === undefined) {
    return isDown ? undefined : prompts.at(-1)
  }
  const { line, scrolledOff } = top
  if (isDown) {
    return prompts.find(prompt => prompt.line > line)
  }

  return prompts.findLast(prompt => prompt.line < line || (prompt.line === line && scrolledOff > 0))
}

// Scroll the target prompt to the top of the screen. Claude Code doesn't always report rows that a jump takes off the
// screen, so start the record of what is on screen afresh, from the prompt now at the top. The first scroll can land a
// few rows short of a prompt whose surroundings weren't laid out yet, so scroll again once they are.
async function jump($: EngineInterface, isDown: boolean) {
  const order = await readOrder($)
  const target = order === undefined ? undefined : findTarget(order, isDown)
  if (target !== undefined) {
    lastJump = { id: target.id, reports }
    shown.clear()
    shown.set(target.id, 0)
    await $.ui.scroll({ to: { requestId: target.id }, block: 'start' })
    await $.clock.sleep(RESCROLL_DELAY_MS)
    await $.ui.scroll({ to: { requestId: target.id }, block: 'start' })
  }
}

// Note which of a transcript row's rows are on screen, when Claude Code reports it.
function track(e: RenderInput) {
  const onScreen = 'onScreen' in e.props ? e.props.onScreen : undefined
  if (e.surface !== 'terminal' || onScreen === undefined) {
    return
  }
  reports += 1
  if (onScreen === null) {
    shown.delete(e.requestId)
  } else {
    shown.set(e.requestId, onScreen.first)
  }
}

export const register: Register = on => {
  on('classic.SessionStart', (_$, e, next) => {
    transcriptPath = e.transcript_path

    return next(e)
  })

  on('classic.UserPromptSubmit', (_$, e, next) => {
    transcriptPath = e.transcript_path

    return next(e)
  })

  on('ui.render', { component: TRACKED }, (_$, e, next) => {
    track(e)

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
          <Button key="previous" label="Previous prompt" action="strip:jump3" onPress={() => jump($, false)} />
          <Button key="next" label="Next prompt" action="strip:jump4" onPress={() => jump($, true)} />
        </Box>
      </Box>
    )
  })
}
