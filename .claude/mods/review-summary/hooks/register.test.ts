import { expect, mock, test } from 'claude-code/testing'

const PATH = '/home/.cache/claude-review/session-1/summary.md'
const SUMMARY = '# Review summary\n\nOld\n'

test("a summary is shown once, under the last review call's row, but not one there from before", async ($, on) => {
  const files: Record<string, string> = { [PATH]: SUMMARY }
  on('fs.read', (_, e) => {
    const text = files[e.path]
    if (text === undefined) {
      throw new Error(`no such file: ${e.path}`)
    }
    return { value: text }
  })
  on('session.id', () => ({ value: 'session-1' }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false } }))
  // The engine's own row
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return h(Text, {}, 'row')
  })
  mock.env(on, { HOME: '/home' })
  const complete = () =>
    $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })
  // The card drawn under the row of call `id`, the same on each surface
  const card = async (id: string) => {
    const found = []
    for (const surface of ['terminal', 'desktop'] as const) {
      const props = { tool_use_id: id, tool: 'Bash', input: {}, isRunning: false, isErrored: false, isInterrupted: false }
      const ui = await $.ui.mount({ plugin: 'review-summary', surface, component: 'ToolUse', props })
      expect(await ui.find({ type: 'Text', text: 'row' })).toBeDefined()
      found.push(await ui.find({ type: 'Markdown' }))
      await ui.unmount()
    }
    expect(found[1]).toEqual(found[0])
    return found[0]
  }

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.tool.call({ tool: 'Bash', command: '~/.claude/review/review.sh start spec.md', tool_use_id: 'start' })
  await complete()
  expect(await card('start')).toBeUndefined()

  // A new review: `review.sh start` deletes the old summary, then the review writes the same text again.
  delete files[PATH]
  await complete()
  await $.tool.call({ tool: 'Bash', command: 'ls', tool_use_id: 'other' })
  await $.tool.call({ tool: 'Bash', command: '~/.claude/review/review.sh respond <<EOF', tool_use_id: 'respond' })
  files[PATH] = SUMMARY
  await complete()
  await complete()
  expect(await card('start')).toBeUndefined()
  expect(await card('other')).toBeUndefined()
  expect(await card('respond')).toMatchObject({ text: '# Review summary\n\nOld' })
})
