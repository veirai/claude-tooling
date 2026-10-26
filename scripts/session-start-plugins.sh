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
# SECURITY: these are third-party repos cloned from HEAD. Each is pinned to its
# first-install SHA via verify_and_pin_sha(). SHA files live in
# ~/.claude/skills/.{name}.sha. Upgrade path: delete .sha, reinstall, validate.
GSTACK_DIR="$HOME/.claude/skills/gstack"
GSTACK_PIN="$HOME/.claude/skills/.gstack.sha"
if [ ! -f "$GSTACK_DIR/SKILL.md" ]; then
  log "Installing gstack skill suite..."
  rm -rf "${GSTACK_DIR}.tmp"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 \
    https://github.com/garrytan/gstack "${GSTACK_DIR}.tmp" 2>/dev/null \
    && mv "${GSTACK_DIR}.tmp" "$GSTACK_DIR" \
    && verify_and_pin_sha "$GSTACK_DIR" "gstack" "$GSTACK_PIN" \
    && log "gstack installed" \
    || log "WARNING: gstack clone failed"
else
  CURRENT_SHA=$(git -C "$GSTACK_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
  PINNED_SHA=$(cat "$GSTACK_PIN" 2>/dev/null || echo "")
  if [ -n "$PINNED_SHA" ] && [ "$PINNED_SHA" != "$CURRENT_SHA" ]; then
    log "SECURITY WARNING: gstack SHA mismatch — expected $PINNED_SHA, got $CURRENT_SHA"
  fi
  log "gstack already present ($(cat "$GSTACK_DIR/VERSION" 2>/dev/null || echo 'version unknown'))"
fi

TASK_OBSERVER_DIR="$HOME/.claude/skills/task-observer"
TASK_OBSERVER_PIN="$HOME/.claude/skills/.task-observer.sha"
if [ ! -f "$TASK_OBSERVER_DIR/SKILL.md" ]; then
  log "Installing task-observer skill..."
  rm -rf "${TASK_OBSERVER_DIR}.tmp"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 \
    https://github.com/rebelytics/one-skill-to-rule-them-all "${TASK_OBSERVER_DIR}.tmp" 2>/dev/null \
    && mv "${TASK_OBSERVER_DIR}.tmp" "$TASK_OBSERVER_DIR" \
    && verify_and_pin_sha "$TASK_OBSERVER_DIR" "task-observer" "$TASK_OBSERVER_PIN" \
    && log "task-observer installed" \
    || log "WARNING: task-observer clone failed"
else
  CURRENT_SHA=$(git -C "$TASK_OBSERVER_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
  PINNED_SHA=$(cat "$TASK_OBSERVER_PIN" 2>/dev/null || echo "")
  if [ -n "$PINNED_SHA" ] && [ "$PINNED_SHA" != "$CURRENT_SHA" ]; then
    log "SECURITY WARNING: task-observer SHA mismatch — expected $PINNED_SHA, got $CURRENT_SHA"
  fi
  log "task-observer already present"
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
"$(dirname "$0")/test-plugins.sh" && log "All checks passed." || log "WARNING: Some checks failed — see above."

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
