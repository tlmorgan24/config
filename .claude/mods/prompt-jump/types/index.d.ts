export type TranscriptPath = string  // This session's transcript, as the classic hooks' `transcript_path` gives it

declare module 'claude-code' {
  interface PluginState {
    'prompt-jump': { transcriptPath: TranscriptPath }
  }
}
