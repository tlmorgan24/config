export type TranscriptPath = string  // This session's transcript, as the classic hooks' `transcript_path` gives it

declare module 'claude-code' {
  interface PluginState {
    'copy-session': { transcriptPath: TranscriptPath }
  }
}
