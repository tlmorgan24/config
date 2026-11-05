export type ToolUseId = string  // A tool call's id, as `tool.call` gives it
export type Cards = Record<ToolUseId, string>  // Each review's summary, by the id of the `review.sh` call that finished it

declare module 'claude-code' {
  interface PluginState {
    'review-summary': { lastCall: ToolUseId | null; cards: Cards }
  }
}
