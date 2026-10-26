#!/bin/bash
# Verifies that every expected plugin is installed AND enabled, and that the
# skill suites and claude-tooling skills are on disk.
# Exit 0 = OK, Exit 1 = something missing.
#
# Keep EXPECTED_PLUGINS identical to the install list in session-start-plugins.sh.

EXPECTED_PLUGINS=(
  "code-review@claude-plugins-official"
  "claude-code-setup@claude-plugins-official"
  "code-simplifier@claude-plugins-official"
  "superpowers@claude-plugins-official"
  "understand-anything@understand-anything"
  "claude-mem@thedotmack"
  "context7@context7-marketplace"
  "security-guidance@knowledge-work-plugins"
  "tinyfish@knowledge-work-plugins"
)

EXPECTED_SKILL_DIRS=(
  "$HOME/.claude/skills/gstack"
  "$HOME/.claude/skills/activate-plugins"
  "$HOME/.claude/skills/session-wrap-up"
)

MISSING=()
INSTALLED=$(claude plugin list 2>/dev/null || echo "")

for plugin in "${EXPECTED_PLUGINS[@]}"; do
  # The entry's Status line follows its "> name@marketplace" header within 4 lines.
  entry=$(echo "$INSTALLED" | grep -F -A4 "> $plugin")
  if [ -z "$entry" ]; then
    MISSING+=("plugin:$plugin")
  elif ! echo "$entry" | grep -q "enabled"; then
    MISSING+=("plugin:$plugin(disabled)")
  fi
done

for dir in "${EXPECTED_SKILL_DIRS[@]}"; do
  if [ ! -f "$dir/SKILL.md" ]; then
    MISSING+=("skill:$(basename "$dir")")
  fi
done

# Upstream drift: superpowers updates itself, so a newer version than the one we
# last reviewed is not an error, but it is a reminder to compare (UPSTREAM.md).
REVIEWED_SUPERPOWERS="7.0.1"
INSTALLED_SUPERPOWERS=$(echo "$INSTALLED" | grep -F -A2 "> superpowers@" | sed -n 's/.*Version: //p' | head -1)
NEWEST=$(printf '%s\n%s\n' "$INSTALLED_SUPERPOWERS" "$REVIEWED_SUPERPOWERS" | sort -V | tail -1)
if [ -n "$INSTALLED_SUPERPOWERS" ] && [ "$INSTALLED_SUPERPOWERS" != "$REVIEWED_SUPERPOWERS" ] && [ "$NEWEST" = "$INSTALLED_SUPERPOWERS" ]; then
  echo "NOTE: superpowers is $INSTALLED_SUPERPOWERS, last reviewed $REVIEWED_SUPERPOWERS — compare per UPSTREAM.md"
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "OK: All ${#EXPECTED_PLUGINS[@]} plugins enabled + ${#EXPECTED_SKILL_DIRS[@]} skills present"
  exit 0
else
  echo "MISSING (${#MISSING[@]}): ${MISSING[*]}"
  exit 1
fi
