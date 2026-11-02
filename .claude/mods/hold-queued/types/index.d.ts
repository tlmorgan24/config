export type Held = string[]  // Messages waiting to be submitted, oldest first
export type Editing = number | null  // Index in `Held` of the message taken back for editing

declare module 'claude-code' {
  interface PluginState {
    'hold-queued': { held: Held; editing: Editing }
  }
}
