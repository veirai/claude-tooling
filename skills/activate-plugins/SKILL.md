---
name: activate-plugins
description: Full session startup sequence — installs plugins, reads canonical state (SESSION-MEMORY.md + STATUS.md), checks MCPs, audits skills, reads trio coordination, and prints habit triggers. Invoke when the user says "activate-plugins", "ladda mina plugins", "aktivera mina plugins", "kör plugin-setupen", or at the start of any working session.
---

# Full session startup sequence

Run this full startup sequence and report a compact status table at the end.
Run all independent steps in parallel.

**After the move (2026-10-10/12) all three apps run on our own Supabase (org Veirai,
Stockholm): Landing `uxssabiwybfdzjdiiewd`, HQ `kvzzftmdnonpzjvjkfwr`, Web
`ovwioezbsqencnrplpck`.** Sofia/Lovable builds, deploys and operates nothing any more. The
old Lovable projects are paused rollback copies with stale data, so never read state from
them, and that includes the old `HQ`, `Landing` and `Web` connectors.

## 0. Project threads (claude.ai Projects)
Cloud threads start without the repos, so the SessionStart hook hasn't run yet. First
attach `veirai/hq` (`add_repo`), clone it and call `register_repo_root`. The hook then
installs the plugins and injects SESSION-MEMORY.md on the next turn.

## 1. Plugins
Run the canonical installer from GitHub. It works whatever folder the session started in
(a single repo or the whole workspace, where no repo's SessionStart hook runs), it is
idempotent, and it ends by running `test-plugins.sh`:

```bash
D=$(mktemp -d); B=https://raw.githubusercontent.com/veirai/claude-tooling/main/scripts
curl -fsSL "$B/session-start-plugins.sh" -o "$D/session-start-plugins.sh" \
  && curl -fsSL "$B/test-plugins.sh" -o "$D/test-plugins.sh" \
  && bash "$D/session-start-plugins.sh"
```

Newly installed plugins load into the running session within a few seconds. Then confirm
they actually loaded, not just installed: the skill list must show `superpowers:*`,
`claude-mem:*`, `understand-anything:*`, `tinyfish:*` and `gstack`, and the agent list
`understand-anything:*` agents.
Report: the `OK:`/`MISSING` line from the test + which plugin skills are visible.
If the download fails, use the manual fallback at the bottom of this file.

## 2. Shared Brain (Memory) + Canonical State Read-In
Run all sub-steps in parallel.

**claude-mem plugin context:**
Call `mcp__plugin_claude-mem_mcp-search__session_start_context` with:
- projects: "hq,landing,user,web" (claude-mem names projects after the folder a session ran
  in: `user` is a session opened over the whole workspace; `veirai/hq`-style names return nothing).
  On a local Mac session the project is the folder name, e.g. `Veirai`: query `Veirai` as well.
  Check `sqlite3 ~/.claude-mem/claude-mem.db "select project,count(*) from observations group by 1"` if unsure.
Report: how many observations and from which dates, or "empty".
If it says the project has no memory, the start hook's restore probably lost the race against
claude-mem's database. From a web checkout run `bash scripts/mem-backup-import.sh`, then call
the tool again. Report ⚠️ if it's still empty after that, never a silent "first session".
Also report how old the backup is: `git -C /home/user/web fetch -q origin claude-mem-backup &&
git -C /home/user/web log -1 --format=%cr origin/claude-mem-backup`. Older than a day while
sessions have been working = ⚠️ (hq's nightly `memory-health` check will be red too).

**Cloud sync** (local sessions only): check `http://127.0.0.1:<port>/api/sync/status` (port: `$CLAUDE_MEM_WORKER_PORT`, else
`CLAUDE_MEM_WORKER_PORT` in `~/.claude-mem/settings.json`, else 37700)
— report configured+reachable ✅ or warn ⚠️ to run `claude-mem:cloud-sync`.
In remote sessions: N/A — git-backed backup loop handles both import (session start) and export
(session end via `mem-backup-export.sh` → `claude-mem-backup` branch). No cloud-sync required.

**SESSION-MEMORY.md** (the canonical cross-session memory — auto-injected by brain-log hook):
If the `─── SESSION-MEMORY.md ───` block appears in your context (injected by the SessionStart hook):
→ extract and summarize: locked decisions, active in-flight PRs, open human decisions, key system IDs.
If NOT visible (hook failed or web/landing session):
→ fetch immediately: `mcp__github__get_file_contents(owner:veirai, repo:hq, path:public/docs/shared-memory/SESSION-MEMORY.md, ref:refs/heads/main)` — do this before any other work.
Read its "Current state" block first: it wins over older dated entries, and every
"send to Sofia", "Lovable Publish" or `mcp__Lovable__query_database` line below it is history.
Report: 3–5 bullet summary of what's locked + what's active.

**STATUS.md** (ecosystem priority list):
Fetch: `mcp__github__get_file_contents(owner:veirai, repo:hq, path:public/docs/shared-memory/STATUS.md, ref:refs/heads/main)`
Report: version number + last changelog date. If it still carries the "outdated since the
move" banner or lists Sofia deploy queues, report ⚠️ outdated and don't treat its 🟡 rows as
live work: open `larm`/`beslut` issues (§5) are the live list.

If `mcp__github__*` isn't available (local Mac: only `gh` is set up), fetch both files with
`gh api "repos/veirai/hq/contents/public/docs/shared-memory/<FILE>?ref=main" --jq .content | base64 -d`.

**Cross-session brain log** (may already be injected by hook under `─── Cross-session ───`):
If injected: note the entries. If not: no action needed (hook only runs when log files exist this month).

> **Saving rule (Fredrik 2026-09-30) — read and internalize now:**
> Write to SESSION-MEMORY.md only when a decision is locked, and once at session end.
> Batch updates into one write; never write an unverified conclusion. Every write is a
> commit to hq main that costs CI minutes (it drove ~half of Sept 2026's Actions usage).
> Mechanic: (a) get SHA → `mcp__github__get_file_contents(...SESSION-MEMORY.md, ref:refs/heads/main)`
>           (b) `mcp__github__create_or_update_file(owner:veirai, repo:hq, branch:main, sha:..., content:<full updated file>)`
> Re-fetch SESSION-MEMORY.md before each major new subtask.

## 3. MCPs
Call `ListConnectors` — list each as ✅ connected+enabled, ⚠️ enabled but unknown state, ❌ disabled in chat.

Expected for Veirai work: **HQ (ny)**, **Landing (ny)**, GitHub, Supabase, Vercel, Sentry,
PostHog, Resend, Context7. Mark the old **HQ**, **Landing** and **Web** connectors as
"old (Lovable copy)" instead of ✅ or ❌: they answer, but with data frozen at the move.
Lovable is only needed for the AI gateway and the rollback copies until hq#766 closes them.
In cloud sessions the context7 *plugin's* own MCP server (`plugin:context7:context7`) can't
get through the network proxy; the claude.ai Context7 connector (`mcp__Context7__*`) is the
working path there, so report the plugin server as ⚠️ only if that connector is missing too.

## 4. Skills — full inventory check
Confirm ALL of the following are present in the skill list. Missing = ❌ gap.

**Plugin suites:** superpowers, claude-mem, understand-anything, code-review, context7, code-simplifier,
claude-code-setup, security-guidance, tinyfish
**Skill suites:** gstack
**Veirai workflow skills** (from `hq/.claude/skills`): secret-detection,
three-role-code-review, verify-before-claiming-done, pre-approve-architecture-check,
investigate-root-cause, internal-autoplan,
independent-diff-review, veirai-visual-review, service-index-lookup,
decision-queue, guided-handoff, create-migration

## 5. Trio Coordination (read, don't act yet)
Run these in parallel:
- `mcp__HQ_ny__get_coordination_ledger` — active work claims across trio; flag any WIP row older than 14 days as ⚠️ stale
- `mcp__HQ_ny__list_active_work_claims` — intra-HQ session claims (§4.1)
- `mcp__HQ_ny__get_urgent_triage` — anything urgent right now
- `mcp__HQ_ny__get_ecosystem_status` — live health of HQ/Web/Landing
- Open `larm` and `beslut` issues in veirai/hq (the one place for alarms and decisions):
  `gh api "repos/veirai/hq/issues?labels=larm&state=open"` and the same with `labels=beslut`
  (REST only; GraphQL is blocked in cloud sessions)
- `mcp__claude-code-remote__list_sessions` (mine: true) — detect parallel sessions in the same repos; include task_summary if present

Council runs on demand only (paused 2026-09-24), so open deliberations are no longer a
startup check. If HQ (ny) isn't connected, say so in the table and use the issue lists;
never fall back to the old `mcp__HQ__*` tools.

Report: summarize active claims, conflicts, stale ledger rows, alarms, open decisions,
and parallel sessions that could cause overlap.

## 6. Status Report
Output a single compact table:

| Check | Status | Notes |
|---|---|---|
| Plugins | ✅/❌ | N/9 plugins |
| claude-mem | ✅/⚠️ | observations injected + backup age |
| Cloud sync | ✅/⚠️/N/A | configured+reachable / warning / remote session |
| SESSION-MEMORY | ✅/⚠️ | injected by hook / manually fetched / not found |
| STATUS.md | ✅/⚠️ | vX.XX loaded, last entry date, outdated banner? |
| MCPs | N active | list any ❌ and any old Lovable-era connectors |
| Plugin suites | ✅/❌ | superpowers, claude-mem, understand-anything, code-review, context7, code-simplifier, claude-code-setup, security-guidance, tinyfish |
| Skill suites | ✅/❌ | gstack |
| Veirai skills | N/12 present | list any ❌ missing |
| Intra-HQ claims | N claims | list scope+owner if any |
| Trio ledger WIP | N rows (N stale) | flag stale rows |
| Alarms (`larm`) | N open | list if any |
| Decisions (`beslut`) | N open | list with age |
| Parallel sessions | N running | list titles + task_summary for overlap |

After the table: one-line summary of what to be aware of before starting work today.

## 7. Habit Triggers
Print this reminder table:

| Situation | Invoke |
|---|---|
| Designing new test coverage or writing tests | `superpowers:test-driven-development` |
| PR with architectural scope (new edge, schema, contract, shared signal type) | `three-role-code-review` |
| Before merging any PR you own | `verify-before-claiming-done` |
| Before implementing a new feature or integration | `pre-approve-architecture-check` |
| Debugging a non-obvious bug | `investigate-root-cause` |
| Complex multi-step task needing a plan | `internal-autoplan` or `superpowers:writing-plans` |
| Reviewing a diff independently | `independent-diff-review` |
| Code written, before review | `simplify` (code-simplifier) |
| UI/visual work touching Veirai brand | `veirai-visual-review` + `apple-design` |
| Need to find an existing service/edge/tool | `service-index-lookup` |
| New database migration | `create-migration` |
| Shipping a change | Draft PR → CI green → Fredrik writes "merge". Backend deploys run from GitHub workflows (HQ `supabase-deploy.yml`, Web release train, Landing `supabase-deploy.yml`). Never a Sofia request or Lovable Publish. |
| Reading live data | HQ: `mcp__Supabase__execute_sql` on `kvzzftmdnonpzjvjkfwr`. Web: only with Fredrik's explicit ok in the thread. |
| Need a real decision from Fredrik | `decision-queue` (`beslut` issue) |
| Fredrik has to click something in a console | `guided-handoff` |
| Adding or moving a vendor/service | Update `vendors.json` in the same PR |
| Decision locked | Write to SESSION-MEMORY.md (one batched commit, see §2) |
| Long session about to be compressed | One batched SESSION-MEMORY.md checkpoint, not one write per finding |
| Session end | Run `/session-wrap-up`: one batched update of SESSION-MEMORY.md, and STATUS.md + COORDINATION.md if trio-scope. |

Where a superpowers skill and a Veirai skill cover the same step, the Veirai one wins
(the "Plugin skills vs Veirai skills" rule in each repo's CLAUDE.md). Skill corrections
from the session are proposed at wrap-up (`session-wrap-up` step 4b).

---

## Manual fallback (if session-start-plugins.sh missing)

### Register marketplaces
```bash
claude plugin marketplace add anthropics/claude-plugins-official || true
claude plugin marketplace add "Egonex-AI/Understand-Anything#v2.9.0" || true
claude plugin marketplace add "thedotmack/claude-mem#v13.13.1" || true
claude plugin marketplace add upstash/context7 || true
claude plugin marketplace add anthropics/knowledge-work-plugins || true
```

### Install plugins
```bash
claude plugin install code-review@claude-plugins-official       --scope user
claude plugin install claude-code-setup@claude-plugins-official --scope user
claude plugin install code-simplifier@claude-plugins-official   --scope user
claude plugin install superpowers@claude-plugins-official        --scope user
claude plugin install understand-anything@understand-anything   --scope user
claude plugin install claude-mem@thedotmack                     --scope user
claude plugin install context7@context7-marketplace             --scope user
claude plugin install security-guidance@knowledge-work-plugins  --scope user
claude plugin install tinyfish@knowledge-work-plugins           --scope user
```

### Install skill suites
```bash
if [ ! -f ~/.claude/skills/gstack/SKILL.md ]; then
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 \
    https://github.com/garrytan/gstack ~/.claude/skills/gstack
fi
```

## Source of truth

Scripts live in `veirai/claude-tooling`. When adding a plugin, update the install list
in `scripts/session-start-plugins.sh`, `EXPECTED_PLUGINS` in `scripts/test-plugins.sh`,
`enabledPlugins` in each repo's `.claude/settings.json`, and the lists in this file.
Each repo's SessionStart hook runs the installer when a session opens inside that repo;
a session opened over the whole workspace runs no repo hook, which is why step 1 runs it.
