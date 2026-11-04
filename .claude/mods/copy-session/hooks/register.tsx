import type { EngineInterface, Register } from 'claude-code'

// /copy-session: copy this session's transcript, as `_claude-transcript` prints it, to the clipboard, e.g. to search it
// with `pbpaste | rg`. Runs here, without going to Claude.

let transcriptPath: string | undefined

async function copy($: EngineInterface): Promise<string> {
  if (transcriptPath === undefined) {
    return 'No transcript yet'
  }
  const result = await $.process
    .run(['zsh', '-fc', 'set -o pipefail; _claude-transcript $1 | pbcopy', 'zsh', transcriptPath])
    .catch((error: unknown) => ({ exitCode: 1, stderr: String(error) }))

  return result.exitCode === 0 ? 'Copied transcript' : `Couldn't copy transcript: ${result.stderr.trim()}`
}

export const register: Register = on => {
  on('classic.SessionStart', ($, e, next) => {
    transcriptPath = e.transcript_path
    // Run at once even mid-turn, as it only reads the transcript.
    const description = "Copy this session's transcript to the clipboard"
    $.command.register({ name: 'copy-session', description, immediate: true }).catch(() => undefined)

    return next(e)
  })

  on('classic.UserPromptSubmit', (_$, e, next) => {
    transcriptPath = e.transcript_path

    return next(e)
  })

  on('command.run', { command: 'copy-session' }, async $ => ({ text: await copy($) }))
}
