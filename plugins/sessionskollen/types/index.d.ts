export type Group = 'action' | 'working' | 'review' | 'idle'

export type Row = {
  id: string
  title: string
  group: Group
  doing: string
  needs: string
  model: string
  effort: string
  costUsd: number
  contextPct: number
  kind: 'rutin' | 'komplex' | ''
  tip: string
  updatedAt: string
}

/** An open hq issue labelled beslut or larm, read from the HQ signal hub. */
export type HubItem = {
  number: number
  title: string
  kind: 'beslut' | 'larm'
  /** true when Fredrik is the one who has to act (unanswered beslut, or a larm marked fredrik-behovs) */
  isForFredrik: boolean
  ageDays: number
}

/** An open, non-draft PR in hq, web or landing: only Fredrik's "merge" is left. */
export type MergeItem = {
  repo: 'hq' | 'web' | 'landing'
  number: number
  title: string
  /** CI on the PR's head: green, red, still running, or unknown (no checks or the read failed) */
  ci: 'green' | 'red' | 'running' | 'unknown'
  ageDays: number
}

/** An archived session whose last words were a question that never got an answer. */
export type Forgotten = { id: string; title: string; question: string; day: string }

export type Overlap = { a: string; b: string; why: string }

export type Usage = {
  days: number
  sessions: number
  totalUsd: number
  opusUsd: number
  opusRoutineUsd: number
  opusRoutineCount: number
  byModel: { model: string; usd: number; count: number }[]
}

export type Snapshot = {
  at: number
  rows: Row[]
  hub: HubItem[]
  merges: MergeItem[]
  forgotten: Forgotten[]
  overlaps: Overlap[]
  summary: string
  usage: Usage
  rateLimit: string
  error: string
}

declare module 'claude-code' {
  interface PluginState {
    sessionskollen: {
      snapshot: Shaped<Snapshot | null>
      isBusy: boolean
    }
  }
}
