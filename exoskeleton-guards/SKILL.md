---
name: exoskeleton-guards
description: Stage skill that installs the four guards — non-AI Sentinels that sit between AI agents and any destructive action. Includes the Pre-Change Protocol Hook, Schema-Verify, the pre-commit Parity Check, and the post-commit Knowledge-Graph Refresh. Use after CLAUDE.md is written. The single most important pattern in the stack — the asymmetry that makes the whole exoskeleton shippable.
---

# Exoskeleton — The Four Guards

Installs the four non-AI guards described in the [builder's guide §09](https://christianmerkel.com/two-suits/builders-guide#sentinels). **Bash and python only. No AI in any guard.**

## When to invoke

- Called by `/exoskeleton-install` as the third stage (in parallel with `/exoskeleton-manual`)
- Or invoked standalone when the user already has CLAUDE.md and wants the discipline made mechanical

## What this skill creates

```
<project-root>/
├── .claude/
│   └── hooks/
│       ├── pre-change-protocol.sh  ← Sentinel 1
│       ├── schema-verify.sh         ← Sentinel 2
│       └── kg-staleness-check.sh    ← auxiliary nudge
├── .githooks/
│   ├── pre-commit                   ← Sentinel 3 (parity check)
│   └── post-commit                  ← Sentinel 4 (KG refresh)
└── parity-check.sh.template         ← per-entity layer walker (you customize this)
```

After installation, runs:

```bash
git config core.hooksPath .githooks
```

So the git hooks are activated and travel with the repo.

## Walkthrough

### Step 1 — Copy templates

For each template in `templates/hooks/` and `templates/githooks/`, copy it to its destination. Replace placeholders:

- `<PROJECT_SLUG>` — kebab-case version of the project name (Q1 from the orchestrator)
- `<LAYERS_LIST>` — the user's layer names
- `<YOUR_LIVE_DB_TOOL_NAME>` — the MCP server name the user installed (default: `mcp__mariadb__execute_sql`; or `mcp__postgres__execute_sql` etc. depending on `<PRIMARY_DB>`)
- `<YOUR_KG_QUERY_TOOL_NAME>` — the KG-store MCP name (if installed; if not, leave the placeholder and document)

### Step 2 — Make scripts executable

```bash
chmod +x .claude/hooks/*.sh
chmod +x .githooks/pre-commit
chmod +x .githooks/post-commit
```

### Step 3 — Wire git hooks

```bash
git config core.hooksPath .githooks
```

This makes `.githooks/` the source for git hooks, so `git commit` actually runs the pre-commit check.

### Step 4 — Verify syntax

Run `bash -n` on each shell script to catch syntax errors:

```bash
for f in .claude/hooks/*.sh .githooks/pre-commit .githooks/post-commit; do
  bash -n "$f" && echo "OK $f" || echo "FAIL $f"
done
```

All should be OK.

### Step 5 — Run a smoke test

Try a controlled action that the guards should refuse:

1. Test Sentinel 2 (Schema-Verify) — try a destructive SQL via the live-DB MCP without first inspecting the table. The guard should refuse.
2. Test Sentinel 3 (Parity Check) — make a one-line edit to a synced file, try to commit. The gate should run (and should pass since you only touched one layer).

If either fails to fire, the wiring is wrong. Surface the failure to the user before moving on.

## What each Sentinel does

### Sentinel 1 — Pre-Change Protocol Hook
Fires on `Edit | Write | MultiEdit` tool calls when the file path matches a configured protected pattern (sync-layer files, schema migrations, auth code, etc.). Warns (or blocks, depending on mode) if the AI hasn't queried the knowledge graph for the current shape of the wire this session.

### Sentinel 2 — Schema-Verify
Fires on live-DB tool calls. Parses the SQL for destructive verbs (`INSERT | UPDATE | DELETE | ALTER | DROP | TRUNCATE | RENAME`), extracts the target table, checks a state file for whether that table has been inspected this session with `get_table_schema`. Refuses if not.

### Sentinel 3 — Parity Check (pre-commit)
For each staged file that touches a synced surface, maps the file to an entity, walks each layer (DB column → API field → admin form → public render → mobile schema), computes set-differences. Refuses the commit if any two layers disagree about a field.

### Sentinel 4 — Knowledge-Graph Refresh (post-commit)
Fires after every commit that touches mineable surfaces. Background-runs the KG miner. No-ops gracefully if the KG store isn't yet set up.

## Hard rules

1. **No AI in any Sentinel.** The whole point is the asymmetry. Bash + regex + state file.
2. **Configurable patterns, not hard-coded paths.** Each Sentinel has a configurable list of protected file patterns at the top of the script. The user customizes for their project.
3. **Warn-first, then block.** Default mode for new installations is WARN. The user upgrades to BLOCK once they've seen the Sentinel fire a few times and trust it. Document both modes in CLAUDE.md.
4. **Idempotent.** Re-running this skill on the same project must not break existing hooks. Check for existing files; ask before overwriting.

## Output the user should see

When this skill completes:

> Four Sentinels installed.
> Git hooks wired (`core.hooksPath` → `.githooks/`).
> Default mode: WARN. Upgrade to BLOCK once you trust them.
>
> The Parity Check template ships at `parity-check.sh.template`. You'll customize it as your schema stabilizes — the template includes a worked example for one entity, commented out, that you adapt for each of your layers.
>
> Next: invoke `/verify-stack` to confirm the full health check passes.

