import type { EngineInterface, Register } from 'claude-code'

// /copy-session: copy this session's transcript, as `_claude-transcript` prints it, to the clipboard, e.g. to search it
// with `pbpaste | rg`. Runs here, without going to Claude.

// Keep the transcript path in the session's state, not a module variable, so that it survives a reload of the mod (which
// clears module variables and doesn't fire `classic.SessionStart` again).
const transcriptPath = { plugin: 'copy-session', key: 'transcriptPath' } as const

async function copy($: EngineInterface): Promise<string> {
  const { value: path } = await $.state.get(transcriptPath)
  if (path === undefined) {
    return 'No transcript yet'
  }
  const result = await $.process
    .run(['zsh', '-fc', 'set -o pipefail; _claude-transcript $1 | pbcopy', 'zsh', path])
    .catch((error: unknown) => ({ exitCode: 1, stderr: String(error) }))

  return result.exitCode === 0 ? 'Copied transcript' : `Couldn't copy transcript: ${result.stderr.trim()}`
}

// Show a failure rather than throw it, so that it doesn't block the session's start or the prompt.
async function saveTranscriptPath($: EngineInterface, path: string): Promise<void> {
  await $.state
    .set(transcriptPath, path)
    .catch((error: unknown) => $.ui.toast(`Couldn't save transcript path: ${String(error)}`))
}

export const register: Register = on => {
  // Register in `session.start`, not `classic.SessionStart`, as only `session.start` is sure to reach the mod once it has
  // loaded (and again after a reload).
  on('session.start', async ($, e, next) => {
    // Run at once even mid-turn, as it only reads the transcript.
    const description = "Copy this session's transcript to the clipboard"
    await $.command
      .register({ name: 'copy-session', description, immediate: true })
      .catch((error: unknown) => $.ui.toast(`Couldn't register /copy-session: ${String(error)}`))

    return next(e)
  })

  on('classic.SessionStart', async ($, e, next) => {
    await saveTranscriptPath($, e.transcript_path)

    return next(e)
  })

  on('classic.UserPromptSubmit', async ($, e, next) => {
    await saveTranscriptPath($, e.transcript_path)

    return next(e)
  })

  on('command.run', { command: 'copy-session' }, async $ => ({ text: await copy($) }))
}
