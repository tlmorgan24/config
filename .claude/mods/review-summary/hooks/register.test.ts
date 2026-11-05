import { expect, mock, test } from 'claude-code/testing'

const PATH = '/home/.cache/claude-review/session-1/summary.md'

test('a summary is shown once when it appears, but not one there from before', async ($, on) => {
  const files: Record<string, string> = { [PATH]: '# Review summary\n\nOld\n' }
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
  mock.env(on, { HOME: '/home' })
  const session = mock.session(on)
  const complete = () =>
    $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await complete()
  expect(session.appended()).toHaveLength(0)

  // A new review: `review.sh start` deletes the old summary, then the review writes the same text again.
  delete files[PATH]
  await complete()
  files[PATH] = '# Review summary\n\nOld\n'
  await complete()
  await complete()
  const rows = session.appended()
  expect(rows).toHaveLength(1)
  expect(rows[0]?.message.type).toBe('system')
  expect(rows[0]?.message.content).toEqual([{ type: 'text', text: '# Review summary\n\nOld' }])
})
