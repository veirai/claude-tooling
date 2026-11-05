import { expect, test } from 'claude-code/testing'

const PANE = {
  plugin: 'sessionskollen',
  component: 'Pane',
  requestId: 'sessionskollen',
  props: { title: 'Sessionskollen', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 60 }, view: {} },
} as const

const now = new Date().toISOString()
const list = { ccr: { data: [
  { id: 's1', title: 'Larm i web', session_status: 'SESSION_STATUS_RUNNING', status_bucket: 'SESSION_STATUS_BUCKET_WORKING', updated_at: now, task_summary: 'fixar larmet' },
  { id: 's2', title: 'Larm i web igen', session_status: 'SESSION_STATUS_RUNNING', status_bucket: 'SESSION_STATUS_BUCKET_WORKING', updated_at: now, task_summary: 'fixar samma larm' },
  { id: 's3', title: 'GDPR-beslut', session_status: 'SESSION_STATUS_IDLE', status_bucket: 'SESSION_STATUS_BUCKET_COMPLETED', updated_at: now, post_turn_summary: { needs_action: 'Välj A eller B' } },
  { id: 's4', title: 'Coachens testplan', session_status: 'SESSION_STATUS_ARCHIVED', status_bucket: 'SESSION_STATUS_BUCKET_COMPLETED', updated_at: now, post_turn_summary: { needs_action: 'Vad väljer du: A, B eller C?' } },
] } }
const detail = { ccr: { configured_model: 'claude-opus-5-5', session_context: { effort_level: 'medium' }, external_metadata: { last_served_model: 'claude-opus-5-5', usage: { cost_usd: 3.5 }, context_usage: { used_tokens: 600, max_tokens: 1000 }, rate_limit_info: { status: 'allowed', resetsAt: 1794427200 } } } }
const issues = (labels: string[]) => ({ issues: labels[0] === 'beslut'
  ? [{ number: 1, title: 'Beslut: pris', created_at: now, labels: ['beslut'] }, { number: 2, title: 'Beslut: gammalt', created_at: now, labels: ['beslut', 'besvarad'] }]
  : [{ number: 3, title: 'Larm: feedback', created_at: now, labels: ['larm'] }] })

function engine(on: Parameters<Parameters<typeof test>[1]>[1], store: Map<string, unknown>, counter = { calls: 0 }) {
  on('command.register', () => ({ value: { command: 'sessioner' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.panes', () => ({ value: [] }))
  on('clock.every', () => ({ value: { cancel: () => {} } }))
  on('clock.now', () => ({ value: Date.now() }))
  on('store.get', (_, e) => ({ value: store.get((e as { key: string }).key) }))
  on('store.set', (_, e) => { const x = e as { key: string; value: unknown }; store.set(x.key, x.value); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  on('ui.toast', () => ({ value: undefined }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('mcp.call', (_, e) => {
    counter.calls += 1
    const c = e as { server: string; tool: string; args: { labels?: string[] } }
    const body = c.server === 'github' ? issues(c.args.labels ?? []) : c.tool === 'list_sessions' ? list : detail
    return { value: { isError: false, content: [{ type: 'text', text: JSON.stringify(body) }] } }
  })
  on('model.classify', () => ({ value: 'rutin' }))
  on('model.complete', () => ({ value: { isAnswered: true, text: JSON.stringify({ summary: 'Ett beslut väntar på dig.', overlaps: [{ a: 'Larm i web', b: 'Larm i web igen', why: 'samma larm' }, { a: 'Finns inte', b: 'Larm i web', why: 'påhittad' }] }), usage: { input_tokens: 1, output_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 } } }))
}

test('väntar på dig samlar sessioner, obesvarade beslut och glömda frågor', async ($, on) => {
  engine(on, new Map())
  await $.command.run({ command: 'sessioner', args: '' })
  await new Promise(r => setTimeout(r, 50))

  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  // s3 frågar, beslut #1 är obesvarat, s4 är en glömd fråga. Beslut #2 är besvarat, larm #3 är agenternas.
  expect((await ui.find({ type: 'Text', text: /Väntar på dig \(3\)/ }))?.text).toBe('Väntar på dig (3)')
  expect((await ui.find({ type: 'Text', text: /hq#1: pris/ })) !== undefined).toBe(true)
  expect((await ui.find({ type: 'Text', text: /hq#2: gammalt/ })) === undefined).toBe(true)
  expect((await ui.find({ type: 'Text', text: /Obesvarad fråga.*Coachens testplan/ })) !== undefined).toBe(true)
  expect((await ui.find({ type: 'Text', text: /agenter jobbar: beslut hq#2, larm hq#3/ })) !== undefined).toBe(true)
  await ui.unmount()
})

test('dubbelarbete visas, påhittade titlar filtreras bort', async ($, on) => {
  engine(on, new Map())
  await $.command.run({ command: 'sessioner', args: '' })
  await new Promise(r => setTimeout(r, 50))

  const ui = await $.ui.mount({ ...PANE, surface: 'mobile' })
  expect((await ui.find({ type: 'Text', text: /"Larm i web" och "Larm i web igen": samma larm/ })) !== undefined).toBe(true)
  expect((await ui.find({ type: 'Text', text: /Finns inte/ })) === undefined).toBe(true)
  expect((await ui.find({ type: 'Text', text: /Sonnet räcker/ })) !== undefined).toBe(true)
  await ui.unmount()
})

test('en färsk delad bild från en annan session återanvänds utan nya anrop', async ($, on) => {
  const counter = { calls: 0 }
  engine(on, new Map(), counter)
  await $.command.run({ command: 'sessioner', args: '' })
  await new Promise(r => setTimeout(r, 50))
  const afterFirst = counter.calls
  expect(afterFirst > 0).toBe(true)
  await $.command.run({ command: 'sessioner', args: '' })
  await new Promise(r => setTimeout(r, 50))
  expect(counter.calls).toBe(afterFirst)
})
