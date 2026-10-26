---
name: session-wrap-up
description: End-of-session wrap-up sequence — flush to SESSION-MEMORY.md, release work claims, hand off open PRs, sync claude-mem, update COORDINATION.md and STATUS.md, check parallel sessions, and print a session summary. Invoke when the user says "wrap up", "session wrap-up", "end session", "avsluta session", or at the natural end of a working session.
---

# End-of-session wrap-up sequence

Run independent steps in parallel where possible.

## 1. Release Work Claims
Call `mcp__HQ_ny__list_active_work_claims` — for any claim this session owns,
call `mcp__HQ_ny__release_work_claim` to free it.

## 2. Open PRs — Subscribe & Hand Off
For any PR opened this session:
- Confirm `subscribe_pr_activity` is active on it
- If session is ending and PR is not yet merged/green, post one status comment
  on the PR summarizing current state and what's left (CI, review, etc.)

## 3. Flush to SESSION-MEMORY.md  ← do this FIRST, before any other wrap-up
Write all unflushed findings, decisions, and key information accumulated this session.
Do not skip — even short sessions capture something worth preserving.

Steps:
(a) Get current SHA + content:
    `mcp__github__get_file_contents(owner:veirai, repo:hq, path:public/docs/shared-memory/SESSION-MEMORY.md, ref:refs/heads/main)`
(b) Add to the relevant sections:
    - **Locked Decisions:** any architectural/policy/direction choices made
    - **Key Findings & Learnings:** root causes confirmed, system behaviors verified, how things actually work
    - **Active Work:** update in-flight PR table — mark merged/closed, add new PRs
    - **Ecosystem Constants:** any new confirmed system IDs, states, or ownership
(c) Write back:
    `mcp__github__create_or_update_file(owner:veirai, repo:hq, branch:main, path:public/docs/shared-memory/SESSION-MEMORY.md, sha:<from step a>, content:<full updated file>)`

Report: what was written, which sections were updated.

## 4. Memory Sync (Shared Brain — claude-mem plugin)
Call `mcp__plugin_claude-mem_mcp-search__important_workflow` for any new
pattern or decision established this session. Log to claude-mem:
- What was built / changed and in which repo (include PR links)
- Any architectural decisions made (and the alternatives considered)
- Any blockers or open questions
- Any coordination patterns that worked or caused friction
- Skills invoked and whether they helped — note any gaps

Then back up claude-mem, so the next session (a fresh container) can restore it:
`bash /home/user/web/scripts/mem-backup-export.sh`
Report the `Pushed N observations` line. If it says the push failed or the worker
was unreachable, report ⚠️ with that line, never "synced". Until 2026-10-26 this export
only ran on a clean session end, which cloud sessions rarely get, and the backup sat
still from 2026-08-26 unnoticed; hq's nightly `memory-health` check now goes red when it
stops.

## 4b. Skill improvements
Look back at the session: did Fredrik correct how a skill worked, did a skill give
wrong or outdated instructions, or did the same manual workaround come up twice?
For each one, propose the change where it gets decided:
- a small, clear fix to a Veirai skill (`hq/.agents/skills/<name>/`) → a draft PR in hq,
  with the correction quoted as the reason
- anything that needs Fredrik's call (a new skill, changing a process, removing one)
  → a `beslut` issue via the `decision-queue` skill
- a gap in a plugin skill (superpowers, claude-mem, …) → note it in
  `veirai/claude-tooling/UPSTREAM.md` under "Gaps to raise"
Report what you proposed, or "no skill corrections this session".

## 5. Update COORDINATION.md
If work touched trio-scope (shared-memory docs, contracts, brand, skills,
`shared_signals` types, or backend functions/migrations):
- Move completed WIP rows from §2 → §3 in
  `hq/public/docs/shared-memory/COORDINATION.md` (commit + push to hq main directly)
- Add a new §2 row if a handoff is pending (e.g. a merged PR whose deploy run
  hasn't gone green yet)
- Bump version header (v1.XX → v1.XX+1) and last-updated date
- Since the move to own Supabase (2026-10-10–12) nothing is published via
  Lovable/Sofia: deploys run in GitHub Actions and Vercel

If work was hq-only (skills, hooks, tooling — not trio-scope): add a §3 wrap-up row
only (no §2 changes needed), still bump version.

## 6. Update STATUS.md
If the session made meaningful progress on anything tracked in STATUS.md:
- Add a dated changelog entry (v2.XX + 1):
  `- **vX.YY (YYYY-MM-DD):** <what changed, which PRs, what's in-flight>. Minor/Major: innehåll/struktur. (Claude Code session \`hq:SESSION-ID\`, YYYY-MM-DD.)`
- Bump the version header and last-updated date at the top of the file
- Push directly to `hq` main (not via PR — minor changelog entries go direct)
- Keep entries short: 2–4 sentences max

## 7. Parallel Session Check
Call `mcp__claude-code-remote__list_sessions` (mine: true) — if other
sessions are still active in the same repos, note any handoff they need.
Use `mcp__claude-code-remote__create_trigger` with `persistent_session_id`
to message them if needed.

## 8. Session Summary
Output this wrap-up block:

---
### Session wrap-up — [date]

**Completed:**
- [bullet list of what was done, with PR/commit links]

**Open / in-flight:**
- [PRs still open, CI pending, deliberations awaiting human, etc.]

**Handoffs needed:**
- [Sofia/Lovable publish, parallel session coordination, human decisions, etc.]

**SESSION-MEMORY.md:** [updated — which sections, what was added]

**Coordination ledger:** [updated vX.XX / not needed — reason]

**STATUS.md:** [updated vX.XX in repo X / not needed — reason]

**Remembered to claude-mem:**
- [what was written via important_workflow]
- Backup: [Pushed N observations / ⚠️ failed: reason]

**Skill improvements proposed:** [PR/issue links / none]

**Claims released:** [N]
---
