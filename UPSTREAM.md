# External plugins and skills we follow

Some of our skills come from, or overlap with, projects we don't control. They keep
improving. This file is where we record which version we last reviewed, so new
functionality doesn't pass us by and changes don't slip in unread.

`scripts/test-plugins.sh` prints a `NOTE:` at every session start when the installed
superpowers is newer than the version below. That note is the trigger to do a review.

## How to review a new version

1. Read the release notes and the diff of `skills/` and `hooks/` since the version below.
2. For each change, ask three things. Does it collide with a Veirai skill or with the
   "Plugin skills vs Veirai skills" rule in each repo's CLAUDE.md? Does it bring something
   we should copy into a Veirai skill? Does it change what loads at session start?
3. Make the changes in a PR (hq for Veirai skills, here for scripts), then update the
   version below in the same PR.

## superpowers (obra/superpowers, MIT, via claude-plugins-official)

- **Last reviewed:** v7.0.1 (2026-10-21), on 2026-10-26.
- **How it updates:** by itself. Every new cloud session installs the latest version in
  Anthropic's marketplace, which can lag upstream: on 2026-10-26 it still served 7.0.0
  while upstream was at 7.0.1. About two upstream releases a month.
- **What we use:** the plugin as installed, under the CLAUDE.md precedence rule.
  `superpowers:test-driven-development` replaces our frozen 2026-08 copy.
- **What we deliberately override:** its startup hook injects "if there's a 1% chance a
  skill applies, you must use it" every session and after every compaction. Our CLAUDE.md
  rule puts the Veirai process skills first and limits brainstorming to real uncertainty.
  From v7.0.1, brainstorming also writes a design doc and builds nothing until it's
  approved; the same rule covers that.
- **Taken over from v7.0.1:** skills over 20,000 characters lose their tail after a
  compaction. `emil-design-eng` and `apple-design` were split into `references/`
  (hq#928).
- **Our skills built on it:** `independent-diff-review` (adapted from
  `requesting-code-review`). Re-read it against upstream when that skill changes.

## gstack (garrytan/gstack)

- **Pinned:** commit `2f8ba2a665a22a5cc2c11337059ee8fe22df4773` (2026-10-26), set as
  `GSTACK_SHA` in `scripts/session-start-plugins.sh`.
- **How it updates:** only when we change the pin. The old per-container pin file never
  survived a session, so every session used to install the newest code unchecked.
- **Our skills built on it:** `investigate-root-cause`, `internal-autoplan`.

## task-observer (rebelytics/one-skill-to-rule-them-all, CC-BY-4.0) — removed

- **Removed:** 2026-10-26, at v3.8.0. It logged observations inside the container, so
  nothing survived a session, and its weekly review never had anything to review.
- **What replaced it:** `session-wrap-up` step 4b, which proposes skill corrections as an
  hq PR or a `beslut` issue.
- **Still worth watching:** it releases weekly. Look at its release notes now and then
  for ideas to copy into step 4b. It has a cloud mode that commits observations to a
  repository via PR; if we ever want the full log back, that mode is the way.

## Gaps to raise

Gaps found in plugin skills during sessions (from `session-wrap-up` step 4b).

- (none yet)
