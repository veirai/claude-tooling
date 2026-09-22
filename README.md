# claude-tooling

Central source of truth for Claude Code plugins, skills, and session setup for the Veirai ecosystem.

## What's included

| Path | Purpose |
|------|---------|
| `scripts/session-start-plugins.sh` | Registers marketplaces, installs all plugins, clones gstack |
| `scripts/test-plugins.sh` | Verifies all 7 plugins + gstack are present (exit 0 = OK) |
| `configs/launcher-settings.json` | `.claude/settings.json` template with the SessionStart auto-sync hook |
| `skills/activate-plugins/` | Skill that triggers plugin setup on demand |
| `skills/task-observer/` | Task observer skill suite |

## Plugins managed

- `code-review` — code review skill
- `claude-code-setup` — project setup helpers
- `code-simplifier` — refactoring and simplification
- `superpowers` — extended agent capabilities
- `understand-anything` — codebase analysis
- `claude-mem` — persistent memory
- `context7` — library documentation lookup

Plus the **gstack** skill suite (git-cloned from `garrytan/gstack`).

## One-time setup for a new Claude Code environment

### 1. Register marketplaces

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add "Egonex-AI/Understand-Anything#v2.9.0"
claude plugin marketplace add "thedotmack/claude-mem#v13.13.1"
claude plugin marketplace add upstash/context7
```

### 2. Install plugins

```bash
claude plugin install code-review@claude-plugins-official       --scope user
claude plugin install claude-code-setup@claude-plugins-official --scope user
claude plugin install code-simplifier@claude-plugins-official   --scope user
claude plugin install superpowers@claude-plugins-official        --scope user
claude plugin install understand-anything@understand-anything   --scope user
claude plugin install claude-mem@thedotmack                     --scope user
claude plugin install context7@context7-marketplace             --scope user
```

### 3. Add the SessionStart hook

Copy `configs/launcher-settings.json` to your project's `.claude/settings.json` (or merge the `hooks` block into your existing file). This hook runs on every session start and:

1. Clones (or pulls) this repo to `/tmp/veirai-claude-tooling`
2. Copies the latest scripts to `~/.claude/`
3. Copies all skills to `~/.claude/skills/`
4. Runs `session-start-plugins.sh` to ensure everything is installed

```bash
cp configs/launcher-settings.json /path/to/project/.claude/settings.json
```

### 4. Add Bash permissions to `~/.claude/settings.json`

The hook needs these permissions in your user settings:

```json
{
  "permissions": {
    "allow": [
      "Bash(claude plugin *)",
      "Bash(git clone *)",
      "Bash(git -C * pull *)",
      "Bash(cp * ~/.claude/*)",
      "Bash(chmod +x ~/.claude/*)"
    ]
  }
}
```

### 5. Verify

```bash
claude plugin list
./scripts/test-plugins.sh
```

## Keeping in sync

- Edit `scripts/session-start-plugins.sh` when adding or removing plugins.
- Update `scripts/test-plugins.sh` to match.
- Update `skills/activate-plugins/SKILL.md` if the trigger phrases change.
- The hook in `configs/launcher-settings.json` is self-updating — it pulls this repo on every session start.
