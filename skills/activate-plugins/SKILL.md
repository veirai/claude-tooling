---
name: activate-plugins
description: Full session startup sequence — installs plugins, reads canonical state (SESSION-MEMORY.md + STATUS.md), checks MCPs, audits skills, reads trio coordination, and prints habit triggers. Invoke when the user says "activate-plugins", "ladda mina plugins", "aktivera mina plugins", "kör plugin-setupen", or at the start of any working session.
---

# Full session startup sequence

Run this full startup sequence and report a compact status table at the end.
Run all independent steps in parallel.

## 1. Plugins
Run `~/.claude/session-start-plugins.sh && ~/.claude/test-plugins.sh`
Report: pass/fail + plugin count

If the scripts don't exist (fresh container before the hook has run), use the
manual fallback at the bottom of this file.

## 2. Shared Brain (Memory) + Canonical State Read-In
Run all sub-steps in parallel.

**claude-mem plugin context:**
Call `mcp__plugin_claude-mem_mcp-search__session_start_context` with:
- projects: "veirai/hq,veirai/web,veirai/landing"
Report: what context was injected, or "first session / empty"

**Cloud sync** (local sessions only): check `http://127.0.0.1:${CLAUDE_MEM_WORKER_PORT:-37700}/api/sync/status`
— report configured+reachable ✅ or warn ⚠️ to run `claude-mem:cloud-sync`.
In remote sessions: N/A — git-backed backup loop handles both import (session start) and export
(session end via `mem-backup-export.sh` → `claude-mem-backup` branch). No cloud-sync required.

**SESSION-MEMORY.md** (the canonical cross-session memory — auto-injected by brain-log hook):
If the `─── SESSION-MEMORY.md ───` block appears in your context (injected by the SessionStart hook):
→ extract and summarize: locked decisions, active in-flight PRs, open human decisions, key system IDs.
If NOT visible (hook failed or web/landing session):
→ fetch immediately: `mcp__github__get_file_contents(owner:veirai, repo:hq, path:public/docs/shared-memory/SESSION-MEMORY.md, ref:refs/heads/main)` — do this before any other work.
Report: 3–5 bullet summary of what's locked + what's active.

**STATUS.md** (live ecosystem priority + status):
Fetch: `mcp__github__get_file_contents(owner:veirai, repo:hq, path:public/docs/shared-memory/STATUS.md, ref:refs/heads/main)`
Report: version number + last 2 changelog entries + any P0/P1 rows that are `🟡 pågår`.

**Cross-session brain log** (may already be injected by hook under `─── Cross-session ───`):
If injected: note the entries. If not: no action needed (hook only runs when log files exist this month).

> **Continuous saving rule — read and internalize now:**
> Write to SESSION-MEMORY.md IMMEDIATELY when: root cause confirmed · decision locked ·
> key ID/state/ownership learned · work block done · ~60 min elapsed.
> Mechanic: (a) get SHA → `mcp__github__get_file_contents(...SESSION-MEMORY.md, ref:refs/heads/main)`
>           (b) `mcp__github__create_or_update_file(owner:veirai, repo:hq, branch:main, sha:..., content:<full updated file>)`
> Re-fetch SESSION-MEMORY.md before each major new subtask.

## 3. MCPs
Call `ListConnectors` — list each as ✅ connected+enabled, ⚠️ enabled but unknown state, ❌ disabled in chat

## 4. Skills — full inventory check
Confirm ALL of the following are present in the skill list. Missing = ❌ gap.

**Plugin suites:** superpowers, claude-mem, understand-anything, code-review, context7
**Skill suites:** gstack, task-observer
**Veirai workflow skills:** secret-detection, deploy, preview-testing,
three-role-code-review, verify-before-claiming-done, pre-approve-architecture-check,
test-driven-development, investigate-root-cause, internal-autoplan,
independent-diff-review, veirai-visual-review, service-index-lookup

## 5. Trio Coordination (read, don't act yet)
Run these in parallel:
- `mcp__HQ__get_coordination_ledger` — active work claims across trio; flag any WIP row older than 14 days as ⚠️ stale
- `mcp__HQ__list_active_work_claims` — intra-HQ session claims (§4.1)
- `mcp__HQ__get_urgent_triage` — anything urgent right now
- `mcp__HQ__get_ecosystem_status` — live health of HQ/Web/Landing
- `mcp__HQ__list_open_deliberations` — open Council decisions needing human
- `mcp__Claude_Code_Remote__list_sessions` (mine: true) — detect parallel sessions in the same repos; include task_summary if present

Report: summarize active claims, conflicts, stale ledger rows, urgent items,
open deliberations, and parallel sessions that could cause overlap.

## 6. Status Report
Output a single compact table:

| Check | Status | Notes |
|---|---|---|
| Plugins | ✅/❌ | N/9 plugins |
| claude-mem | ✅/empty | what context was injected |
| Cloud sync | ✅/⚠️/N/A | configured+reachable / warning / remote session |
| SESSION-MEMORY | ✅/⚠️ | injected by hook / manually fetched / not found |
| STATUS.md | ✅/⚠️ | vX.XX loaded, last entry date |
| MCPs | N/14 active | list any ❌ |
| Plugin suites | ✅/❌ | superpowers, claude-mem, understand-anything, code-review, context7 |
| Skill suites | ✅/❌ | gstack, task-observer |
| Veirai skills | N/12 present | list any ❌ missing |
| Intra-HQ claims | N claims | list scope+owner if any |
| Trio ledger WIP | N rows (N stale) | flag stale rows |
| Urgent items | N items | list if any |
| Open deliberations | N open | awaiting_decision / awaiting_outcome / in_progress |
| Parallel sessions | N running | list titles + task_summary for overlap |

After the table: one-line summary of what to be aware of before starting work today.

## 7. Habit Triggers
Print this reminder table:

| Situation | Invoke |
|---|---|
| Designing new test coverage or writing tests | `test-driven-development` or `superpowers:test-driven-development` |
| PR with architectural scope (new edge, schema, contract, shared signal type) | `three-role-code-review` |
| Before merging any PR you own | `verify-before-claiming-done` |
| Before implementing a new feature or integration | `pre-approve-architecture-check` |
| Debugging a non-obvious bug | `investigate-root-cause` |
| Complex multi-step task needing a plan | `internal-autoplan` or `superpowers:writing-plans` |
| Reviewing a diff independently | `independent-diff-review` |
| UI/visual work touching Veirai brand | `veirai-visual-review` + `apple-design` |
| Need to find an existing service/edge/tool | `service-index-lookup` |
| Finding confirmed / decision locked / key info learned | Write to SESSION-MEMORY.md NOW (see mechanic in §2 above) |
| ~60 min into session | Write SESSION-MEMORY.md checkpoint — don't wait until end |
| After each push/merge/resolved decision | Update STATUS.md + COORDINATION.md if trio-scope. At session end: run `/session-wrap-up`. |

At the start of any task-oriented session — any interaction where you will
use tools and produce deliverables — invoke the task-observer skill before
beginning work. This ensures skill improvement opportunities are captured
throughout the session.

/task-observer

use relevant skills

---

## Manual fallback (if session-start-plugins.sh missing)

### Register marketplaces
```bash
claude plugin marketplace add anthropics/claude-plugins-official || true
claude plugin marketplace add "Egonex-AI/Understand-Anything#v2.9.0" || true
claude plugin marketplace add "thedotmack/claude-mem#v13.13.1" || true
claude plugin marketplace add upstash/context7 || true
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
```

### Install skill suites
```bash
if [ ! -f ~/.claude/skills/gstack/SKILL.md ]; then
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 \
    https://github.com/garrytan/gstack ~/.claude/skills/gstack
fi

if [ ! -f ~/.claude/skills/task-observer/SKILL.md ]; then
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 \
    https://github.com/rebelytics/one-skill-to-rule-them-all ~/.claude/skills/task-observer
fi
```

## Source of truth

Scripts live in `veirai/claude-tooling` — keep them in sync when adding new
plugins. SessionStart hook in `launcher-settings.json` runs
`session-start-plugins.sh` automatically on every new session.
