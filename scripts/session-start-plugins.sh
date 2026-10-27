#!/bin/bash
# Idempotent: register marketplaces + install plugins + install skill suites.
# Runs at every SessionStart — safe to re-run.

LOG_PREFIX="[plugins]"

log() { echo "$LOG_PREFIX $*"; }

# ── INTEGRITY VERIFICATION ────────────────────────────────────────────────────
# Records the commit SHA of each externally-cloned skill on first install and
# warns if it changes on subsequent runs. SHA files live alongside the skill
# dirs. To upgrade a skill: delete its .sha file, reinstall, review the new
# SHA, and update any hardcoded pin once it is confirmed safe.
verify_and_pin_sha() {
  local dir="$1" label="$2" pin_file="$3"
  local current_sha
  current_sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")
  if [ ! -f "$pin_file" ]; then
    echo "$current_sha" > "$pin_file"
    log "$label: pinned to $current_sha — review this SHA before trusting"
  elif [ "$(cat "$pin_file")" != "$current_sha" ]; then
    log "SECURITY WARNING: $label SHA changed — expected $(cat "$pin_file"), got $current_sha"
    log "SECURITY WARNING: removing $label — re-run after manual review"
    rm -rf "$dir" "$pin_file"
    return 1
  fi
  return 0
}

# ── MARKETPLACES ──────────────────────────────────────────────────────────────
log "Registering marketplaces..."
claude plugin marketplace add anthropics/claude-plugins-official          2>/dev/null || true
claude plugin marketplace add "Egonex-AI/Understand-Anything#v2.9.0"      2>/dev/null || true
claude plugin marketplace add "thedotmack/claude-mem#v13.13.1"             2>/dev/null || true
claude plugin marketplace add upstash/context7                             2>/dev/null || true
claude plugin marketplace add anthropics/knowledge-work-plugins            2>/dev/null || true

# ── PLUGINS ───────────────────────────────────────────────────────────────────
log "Installing plugins..."
claude plugin install code-review@claude-plugins-official             --scope user 2>/dev/null || true
claude plugin install claude-code-setup@claude-plugins-official       --scope user 2>/dev/null || true
claude plugin install code-simplifier@claude-plugins-official         --scope user 2>/dev/null || true
claude plugin install superpowers@claude-plugins-official              --scope user 2>/dev/null || true
claude plugin install understand-anything@understand-anything         --scope user 2>/dev/null || true
claude plugin install claude-mem@thedotmack                           --scope user 2>/dev/null || true
claude plugin install context7@context7-marketplace                   --scope user 2>/dev/null || true
claude plugin install security-guidance@knowledge-work-plugins        --scope user 2>/dev/null || true
claude plugin install tinyfish@knowledge-work-plugins                 --scope user 2>/dev/null || true

# ── SKILL SUITES (git-cloned, not marketplace plugins) ────────────────────────
# SECURITY: gstack is a third-party repo. It is pinned to an exact commit HERE,
# in the script, because a pin file in ~/.claude dies with the container: every
# cloud session used to clone HEAD unchecked. To upgrade: review the new commit
# upstream, then change GSTACK_SHA in a PR (see UPSTREAM.md).
GSTACK_SHA="2f8ba2a665a22a5cc2c11337059ee8fe22df4773"
GSTACK_DIR="$HOME/.claude/skills/gstack"
CURRENT_SHA=$(git -C "$GSTACK_DIR" rev-parse HEAD 2>/dev/null || echo "none")
if [ "$CURRENT_SHA" != "$GSTACK_SHA" ]; then
  log "Installing gstack at pinned ${GSTACK_SHA:0:12} (found: ${CURRENT_SHA:0:12})..."
  rm -rf "$GSTACK_DIR" "${GSTACK_DIR}.tmp"
  mkdir -p "${GSTACK_DIR}.tmp" \
    && git -C "${GSTACK_DIR}.tmp" init -q \
    && git -C "${GSTACK_DIR}.tmp" remote add origin https://github.com/garrytan/gstack \
    && GIT_LFS_SKIP_SMUDGE=1 git -C "${GSTACK_DIR}.tmp" fetch -q --depth 1 origin "$GSTACK_SHA" \
    && git -C "${GSTACK_DIR}.tmp" checkout -q FETCH_HEAD \
    && mv "${GSTACK_DIR}.tmp" "$GSTACK_DIR" \
    && log "gstack installed" \
    || log "WARNING: gstack install failed"
else
  log "gstack already at pinned ${GSTACK_SHA:0:12}"
fi

# task-observer was removed (Fredrik 2026-10-26): its log lived in the container
# and never survived a session. The container image may still ship a copy, so
# take it out; skill corrections are proposed at wrap-up instead.
rm -rf "$HOME/.claude/skills/task-observer" "$HOME/.claude/skills/.task-observer.sha"

# ── CLAUDE-MEM BACKUP IN EVERY SESSION ────────────────────────────────────────
# Fredrik 2026-10-27: the claude-mem export should run whatever folder a session
# opens in. The repos' own Stop hooks only run inside that repo, so add the same
# throttled export (at most every 30 min, one at a time) as a user-level Stop hook.
# It takes effect from the next session start.
USER_SETTINGS="$HOME/.claude/settings.json"
MEM_EXPORT_CMD='[ -f /home/user/web/scripts/mem-backup-export.sh ] && bash /home/user/web/scripts/mem-backup-export.sh --if-older-than 1800 || true'
[ -f "$USER_SETTINGS" ] || echo '{}' > "$USER_SETTINGS"
if jq -e --arg c "$MEM_EXPORT_CMD" '[.hooks.Stop[]?.hooks[]?.command] | index($c)' "$USER_SETTINGS" >/dev/null 2>&1; then
  log "claude-mem Stop hook already in user settings"
elif jq --arg c "$MEM_EXPORT_CMD" '.hooks.Stop = ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":$c}]}])' \
    "$USER_SETTINGS" > "${USER_SETTINGS}.tmp" && mv "${USER_SETTINGS}.tmp" "$USER_SETTINGS"; then
  log "claude-mem Stop hook added to user settings (active from the next session start)"
else
  rm -f "${USER_SETTINGS}.tmp"
  log "WARNING: could not add the claude-mem Stop hook to $USER_SETTINGS"
fi

# ── CLAUDE-TOOLING SKILLS + LOCAL COPIES ──────────────────────────────────────
# Puts activate-plugins and session-wrap-up in ~/.claude/skills, and this script
# plus test-plugins.sh in ~/.claude/, whatever folder the session started in.
# From a claude-tooling checkout the files sit next to this script; from the
# thin wrappers in hq/landing/web (which run a temp copy) they're downloaded.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW="https://raw.githubusercontent.com/veirai/claude-tooling/main"
for skill in activate-plugins session-wrap-up; do
  mkdir -p "$HOME/.claude/skills/$skill"
  if [ -f "$SCRIPT_DIR/../skills/$skill/SKILL.md" ]; then
    cp "$SCRIPT_DIR/../skills/$skill/SKILL.md" "$HOME/.claude/skills/$skill/SKILL.md"
  else
    curl -fsSL "$RAW/skills/$skill/SKILL.md" -o "$HOME/.claude/skills/$skill/SKILL.md.tmp" \
      && mv "$HOME/.claude/skills/$skill/SKILL.md.tmp" "$HOME/.claude/skills/$skill/SKILL.md" \
      || log "WARNING: could not fetch skill $skill"
  fi
done
for f in session-start-plugins.sh test-plugins.sh; do
  if [ "$SCRIPT_DIR/$f" != "$HOME/.claude/$f" ]; then
    cp "$SCRIPT_DIR/$f" "$HOME/.claude/$f" 2>/dev/null && chmod +x "$HOME/.claude/$f"
  fi
done

# ── VERIFY ────────────────────────────────────────────────────────────────────
log "Running verification..."
# Run through bash: a downloaded copy (activate-plugins step 1) has no execute bit.
bash "$(dirname "$0")/test-plugins.sh" && log "All checks passed." || log "WARNING: Some checks failed — see above."

# ── MEMORY RESTORE ────────────────────────────────────────────────────────────
# Restore claude-mem observations from the git-backed backup branch.
# Runs in background so it doesn't delay session startup.
MEM_IMPORT="/home/user/web/scripts/mem-backup-import.sh"
if [ -f "$MEM_IMPORT" ]; then
  log "Starting memory restore in background..."
  bash "$MEM_IMPORT" &
fi

# ── CLOUD SYNC CHECK ──────────────────────────────────────────────────────────
# Worker is a local process — skip in remote/cloud sessions where it won't run.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  PORT="${CLAUDE_MEM_WORKER_PORT:-37700}"
  SYNC_STATUS=$(curl -s --connect-timeout 2 "http://127.0.0.1:${PORT}/api/sync/status" 2>/dev/null)
  if echo "$SYNC_STATUS" | grep -q '"configured":true'; then
    log "cloud-sync: configured"
  else
    log "WARNING: cloud-sync not configured or worker not running — run claude-mem:cloud-sync to set up"
  fi
else
  log "cloud-sync: skipped (remote session — git-backed restore is the fallback)"
fi

exit 0
