#!/usr/bin/env node
// PreToolUse hook for mcp__Supabase__execute_sql (Fredrik 2026-11-08).
//
// AGENT-POLICY "Reading is always allowed (Fredrik 2026-11-05)": read-only SQL against
// Web, HQ and Landing needs no question. Writes go only via migrations in a PR, so an
// ad-hoc write is refused here instead of being asked about.
//
//   read-only query on Web/HQ/Landing   -> allow (no prompt)
//   write, or the old Lovable projects  -> deny  (with the reason)
//   staging, unknown project, or a query
//   this check can't prove is read-only -> no decision (the normal prompt decides)
//
// It fails towards asking: anything it doesn't recognise falls back to the normal flow.

import { readFileSync } from 'node:fs';

const LIVE = new Set([
  'ovwioezbsqencnrplpck', // Web
  'kvzzftmdnonpzjvjkfwr', // HQ
  'uxssabiwybfdzjdiiewd', // Landing
  'alisfzjsrcgjxzvsitlo', // Web staging (own, read is harmless)
]);
const OLD_LOVABLE = new Set(['anzpyzdeombjtsktdkwh', 'vrhyefiovchrcbuynypn', 'tutnimlqteoybchsbwbf']);

const WRITE_WORDS = /\b(insert|update|delete|merge|upsert|truncate|drop|alter|create|grant|revoke|copy|call|do|vacuum|analyze|reindex|cluster|comment|lock|refresh|security|reset|set|begin|commit|rollback|savepoint|prepare|execute|listen|notify|discard|import|load|into)\b/;
const READ_START = /^(select|with|explain|show|table|values)\b/;
// Function calls allowed inside a read. Anything else (an app RPC, cron.*, net.*,
// pg_terminate_backend, set_config, nextval …) could change data, so it is not auto-allowed.
const SAFE_CALLS = new Set(`
  select with from where join on and or not in exists any all some over filter partition within as values case when then else
  distinct using lateral array row is null between like ilike similar limit offset group order having union intersect except end nulls date timezone
  count sum min max avg coalesce nullif greatest least now current_date current_timestamp date_trunc date_part extract age
  to_char to_date to_timestamp to_number make_interval interval cast lower upper length char_length octet_length trim btrim ltrim rtrim
  left right substring substr replace split_part position strpos concat concat_ws format md5 encode decode regexp_replace regexp_match
  array_agg string_agg json_agg jsonb_agg json_build_object jsonb_build_object json_object_agg jsonb_object_agg jsonb_array_length
  json_array_length jsonb_array_elements json_array_elements jsonb_each json_each jsonb_object_keys jsonb_typeof jsonb_pretty to_jsonb to_json
  row_to_json array_length array_to_string unnest cardinality generate_series round floor ceil abs mod power sqrt percentile_cont
  percentile_disc mode stddev variance bool_and bool_or every row_number rank dense_rank ntile lag lead first_value last_value
  pg_size_pretty pg_total_relation_size pg_relation_size pg_database_size pg_column_size pg_typeof has_table_privilege
  obj_description col_description format_type current_setting version
`.split(/\s+/).filter(Boolean));

function out(decision, reason, updatedInput) {
  const o = { hookEventName: 'PreToolUse', permissionDecision: decision, permissionDecisionReason: reason };
  if (updatedInput) o.updatedInput = updatedInput;
  process.stdout.write(JSON.stringify({ hookSpecificOutput: o }));
  process.exit(0);
}

// The regex check is only the first layer: Postgres can call a function through
// attribute notation (t.fn means fn(t)) with no parentheses, which no text check can
// rule out (security review 2026-11-09). So an auto-allowed query is also run as a
// read-only transaction: the whole string is one implicit transaction, and
// SET TRANSACTION READ ONLY makes Postgres itself refuse any write in it.
const READ_ONLY_PREFIX = 'set transaction read only;\n';

function isReadOnly(sql) {
  // Only auto-allow SQL whose tokens this check can read unambiguously. Comments,
  // backslashes (E'' escapes), dollar quoting and quoted identifiers can make a regex
  // see a string where Postgres sees code (security review 2026-11-08), so any of
  // them means "no decision" and the normal prompt applies.
  if (/--|\/\*|\\|\$|"/.test(sql)) return false;
  if (/(^|[^a-z0-9_])e'/i.test(sql)) return false;
  // Plain '...' literals ('' is the only escape with standard_conforming_strings).
  const s = sql.replace(/'(?:[^']|'')*'/g, "''").toLowerCase();
  if (s.includes("'") && /'(?!')/.test(s.replace(/''/g, ''))) return false; // unbalanced quote
  const statements = s.split(';').map((t) => t.trim()).filter(Boolean);
  if (statements.length === 0) return false;
  for (const st of statements) {
    if (!READ_START.test(st)) return false;
    if (WRITE_WORDS.test(st)) return false;
    if (/\bfor\s+(update|share|no\s+key|key)\b/.test(st)) return false;
    for (const m of st.matchAll(/([a-z_][a-z0-9_.]*)\s*\(/g)) {
      const name = m[1];
      if (name.includes('.')) {
        const [schema, fn] = name.split('.');
        if (schema !== 'pg_catalog' || !SAFE_CALLS.has(fn)) return false;
      } else if (!SAFE_CALLS.has(name)) {
        return false;
      }
    }
  }
  return true;
}

let input;
try {
  input = JSON.parse(readFileSync(0, 'utf8'));
} catch {
  process.exit(0); // can't read the call: no decision, normal prompt
}
if (input.tool_name !== 'mcp__Supabase__execute_sql') process.exit(0);

const project = String(input.tool_input?.project_id ?? '');
const query = String(input.tool_input?.query ?? '');

if (OLD_LOVABLE.has(project)) {
  out('deny', 'Old Lovable project: its database was deleted 2026-11-02 (hq#766). Never read it as live.');
}
if (!LIVE.has(project)) process.exit(0); // staging cfhhfnhxdvopedlyrqik or unknown: ask as usual

if (isReadOnly(query)) {
  out('allow', 'Read-only SQL, run as a read-only transaction (AGENT-POLICY: reading is always allowed, Fredrik 2026-11-05).',
      { ...input.tool_input, query: READ_ONLY_PREFIX + query });
}
if (WRITE_WORDS.test(query.toLowerCase()) && !READ_START.test(query.trim().toLowerCase())) {
  out('deny', 'Ad-hoc writes to a live database are not allowed. Write a migration in a PR; the deploy workflow applies it after Fredrik merges.');
}
process.exit(0); // unclear (e.g. calls an app function): normal prompt decides
