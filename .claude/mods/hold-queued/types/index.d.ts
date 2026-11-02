export type Held = string[]  // Messages waiting to be submitted, oldest first

declare module 'claude-code' {
  interface PluginState {
    'hold-queued': { held: Held }
  }
}
