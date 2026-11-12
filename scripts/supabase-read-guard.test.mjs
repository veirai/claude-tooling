// Tests for supabase-read-guard.mjs. Run: node --test scripts/*.test.mjs
// Runs the hook the way Claude Code does (JSON on stdin, decision on stdout).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HOOK = fileURLToPath(new URL('./supabase-read-guard.mjs', import.meta.url));
const NAMES = ['Supabase', '53bcef79-e99e-48ae-a6e3-8559d4c9bfea'];
const WEB = 'ovwioezbsqencnrplpck';
const HQ = 'kvzzftmdnonpzjvjkfwr';
const LANDING = 'uxssabiwybfdzjdiiewd';
const STAGING = 'cfhhfnhxdvopedlyrqik';
const OLD = 'vrhyefiovchrcbuynypn';

function decide(tool_name, tool_input) {
  const out = execFileSync('node', [HOOK], { input: JSON.stringify({ tool_name, tool_input }), encoding: 'utf8' });
  if (!out) return { decision: 'none' };
  const o = JSON.parse(out).hookSpecificOutput;
  return { decision: o.permissionDecision, query: o.updatedInput?.query };
}

const CATALOG = `select p.proname, pg_get_functiondef(p.oid)
from pg_trigger t join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'public.organization_members'::regclass and not t.tgisinternal`;

for (const server of NAMES) {
  const sql = `mcp__${server}__execute_sql`;

  test(`${server}: simple select on Web, HQ, Landing is allowed as read-only`, () => {
    for (const project_id of [WEB, HQ, LANDING]) {
      const r = decide(sql, { project_id, query: 'select count(*) from profiles' });
      assert.equal(r.decision, 'allow');
      assert.match(r.query, /^set transaction read only;/);
    }
  });

  test(`${server}: catalog read (pg_get_functiondef, pg_get_triggerdef, ::regclass) is allowed`, () => {
    assert.equal(decide(sql, { project_id: WEB, query: CATALOG }).decision, 'allow');
    assert.equal(decide(sql, { project_id: HQ, query:
      "select tgname, pg_get_triggerdef(oid) from pg_trigger where tgrelid = 'public.x'::regclass" }).decision, 'allow');
    assert.equal(decide(sql, { project_id: LANDING, query:
      "select pg_get_viewdef('public.v'::regclass), pg_get_indexdef(indexrelid) from pg_index limit 5" }).decision, 'allow');
  });

  test(`${server}: writes are denied`, () => {
    assert.equal(decide(sql, { project_id: WEB, query: "insert into profiles(id) values ('x')" }).decision, 'deny');
    assert.equal(decide(sql, { project_id: HQ, query: 'drop table foo' }).decision, 'deny');
  });

  test(`${server}: unknown function calls fall back to the prompt`, () => {
    assert.equal(decide(sql, { project_id: WEB, query: 'select pg_terminate_backend(123)' }).decision, 'none');
    assert.equal(decide(sql, { project_id: WEB, query: 'select my_app_rpc()' }).decision, 'none');
  });

  test(`${server}: staging asks, old Lovable is denied`, () => {
    assert.equal(decide(sql, { project_id: STAGING, query: 'select 1' }).decision, 'none');
    assert.equal(decide(sql, { project_id: OLD, query: 'select 1' }).decision, 'deny');
  });

  test(`${server}: read-only tools are allowed on live projects, ask on staging`, () => {
    assert.equal(decide(`mcp__${server}__list_tables`, { project_id: WEB, schemas: ['public'] }).decision, 'allow');
    assert.equal(decide(`mcp__${server}__get_advisors`, { project_id: HQ, type: 'security' }).decision, 'allow');
    assert.equal(decide(`mcp__${server}__query_logs`, { project_id: LANDING }).decision, 'allow');
    // Without a project the UUID form can't prove it's Supabase, so it asks.
    assert.equal(decide(`mcp__${server}__list_projects`, {}).decision, server === 'Supabase' ? 'allow' : 'none');
    assert.equal(decide(`mcp__${server}__list_tables`, { project_id: STAGING }).decision, 'none');
    assert.equal(decide(`mcp__${server}__list_tables`, { project_id: OLD }).decision, 'deny');
  });

  test(`${server}: migrations and edge deploys are denied`, () => {
    assert.equal(decide(`mcp__${server}__apply_migration`, { project_id: WEB, name: 'x', query: 'select 1' }).decision, 'deny');
    assert.equal(decide(`mcp__${server}__deploy_edge_function`, { project_id: HQ, name: 'x' }).decision, 'deny');
  });

  test(`${server}: other tools get no decision`, () => {
    assert.equal(decide(`mcp__${server}__create_branch`, { project_id: WEB }).decision, 'none');
  });
}

test('other MCP servers are ignored', () => {
  assert.equal(decide('mcp__PostHog__execute_sql', { project_id: WEB, query: 'select 1' }).decision, 'none');
  assert.equal(decide('mcp__HQ_ny__list_tables', { project_id: WEB }).decision, 'none');
  assert.equal(decide('mcp__5234b644-0000-4000-8000-000000000000__search_docs', { query: 'x' }).decision, 'none');
});
