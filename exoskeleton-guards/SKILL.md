---
name: exoskeleton-guards
description: Stage skill that installs the Four Sentinels (Pre-Change Protocol, Schema-Verify, pre-commit Parity, post-commit KG-refresh) AND the five-layer Autonomic Sensing Harness (Ambient Impact, Topic-Area Recall, Self-Stop Watchdog, Correction-Learning, Shape-Coverage). The Sentinels stop the wrong thing; the autonomic layer surfaces the right context. All non-AI, bash + python. Use after CLAUDE.md is written.
---

# Exoskeleton — The Four Guards + The Autonomic Layer

Installs the four non-AI guards described in the [builder's guide §09](https://christianmerkel.com/two-suits/builders-guide#sentinels). **Bash and python only. No AI in any guard.**

## When to invoke

- Called by `/exoskeleton-install` as the third stage (in parallel with `/exoskeleton-manual`)
- Or invoked standalone when the user already has CLAUDE.md and wants the discipline made mechanical

## What this skill creates

```
<project-root>/
├── .claude/
│   └── hooks/
│       ├── pre-change-protocol.sh   ← Sentinel 1
│       ├── schema-verify.sh         ← Sentinel 2
│       ├── kg-staleness-check.sh    ← auxiliary nudge
│       ├── lib-session.sh           ← shared session-state helpers
│       ├── lib-memory.sh            ← pluggable memory backend (mempalace | file | custom)
│       ├── ambient-impact.sh        ← Autonomic 1: peripheral vision
│       ├── recall-topic-area.sh     ← Autonomic 2: deep memory on demand
│       ├── self-stop-watchdog.sh    ← Autonomic 3: drift reflex
│       └── learn-from-correction.sh ← Autonomic 4: lesson-learning flywheel
├── .githooks/
│   ├── pre-commit                   ← Sentinel 3 (parity) + Autonomic 5 (shape-coverage)
│   └── post-commit                  ← Sentinel 4 (KG refresh)
├── qa/
│   ├── lib/entity_shapes.py         ← resolver: file path → entity
│   ├── check-shape-coverage.py      ← Autonomic 5 implementation
│   ├── mine-entity-shapes.py        ← config-driven entity-shape miner
│   └── entity-shapes.config.yaml    ← YOUR entity conventions (you customize this)
└── parity-check.sh.template         ← per-entity layer walker (you customize this)
```

After installation, runs:

```bash
git config core.hooksPath .githooks
```

So the git hooks are activated and travel with the repo.

## Walkthrough

### Step 1 — Copy templates

For each template in `templates/hooks/`, `templates/githooks/`, and `templates/qa/`, copy it to its destination. Replace placeholders:

- `<PROJECT_SLUG>` — kebab-case version of the project name (Q1 from the orchestrator)
- `<App>` — your mobile-app folder name if applicable (e.g. `FefiAdmin`); omit/edit layers if not
- `<LAYERS_LIST>` — the user's layer names
- `<YOUR_LIVE_DB_TOOL_NAME>` — the MCP server name the user installed (default: `mcp__mariadb__execute_sql`; or `mcp__postgres__execute_sql` etc. depending on `<PRIMARY_DB>`)
- `<YOUR_KG_QUERY_TOOL_NAME>` — the KG-store MCP name (if installed; if not, leave the placeholder and document)

The `templates/qa/*` files lay down at the same relative path under the project. `templates/qa/mine-entity-shapes.py.template` → `qa/mine-entity-shapes.py` (drop the `.template` suffix). The config template `qa/entity-shapes.config.yaml.template` → `qa/entity-shapes.config.yaml.template` (keep the suffix — operator copies and customizes manually).

### Step 1b — Ask the memory-backend question

Before installing the memory-using hooks, ask the operator:

> *"The autonomic layer needs a memory store for cross-session lessons + topic-area recall. Pick one:*
> *  (a) **MemPalace** — recommended. Canonical, full diary + KG. Required MCPs install in Stage 0.*
> *  (b) **Local files** — no MCP needed. Lessons land in `qa/.lessons/<date>.md`. Portable but lighter signal.*
> *  (c) **Bring your own** — wire a custom memory provider via `qa/.memory-custom.sh`. After the main install, the `/exoskeleton-memory` skill walks the custom wiring."*

Write the choice into `.claude/settings.json`'s `env` block as `<PROJECT_SLUG>_MEMORY_BACKEND` (mempalace | file | custom). If `(c)`, set a flag so the orchestrator dispatches `/exoskeleton-memory` at the end.

### Step 2 — Make scripts executable

```bash
chmod +x .claude/hooks/*.sh
chmod +x .githooks/pre-commit
chmod +x .githooks/post-commit
chmod +x qa/mine-entity-shapes.py qa/check-shape-coverage.py
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

Try controlled actions that exercise the hooks:

1. Test Sentinel 2 (Schema-Verify) — try a destructive SQL via the live-DB MCP without first inspecting the table. The guard should refuse.
2. Test Sentinel 3 (Parity Check) — make a one-line edit to a synced file, try to commit. The gate should run (and should pass since you only touched one layer).
3. Test the empty-state autonomic layer — without an `entity-shapes.config.yaml`, every entity-aware hook should silently no-op. Confirm by running `python3 qa/mine-entity-shapes.py` and verifying it writes an empty shapes file with `entity_count: 0` and a `note` field explaining dormancy.
4. Test the watchdog — Edit any file twice in a row without a Read in between. Watchdog D1 should fire on the first edit.

If any expected signal fails to fire, the wiring is wrong. Surface to the operator before moving on.

## What each Sentinel does

### Sentinel 1 — Pre-Change Protocol Hook
Fires on `Edit | Write | MultiEdit` tool calls when the file path matches a configured protected pattern (sync-layer files, schema migrations, auth code, etc.). Warns (or blocks, depending on mode) if the AI hasn't queried the knowledge graph for the current shape of the wire this session.

### Sentinel 2 — Schema-Verify
Fires on live-DB tool calls. Parses the SQL for destructive verbs (`INSERT | UPDATE | DELETE | ALTER | DROP | TRUNCATE | RENAME`), extracts the target table, checks a state file for whether that table has been inspected this session with `get_table_schema`. Refuses if not.

### Sentinel 3 — Parity Check (pre-commit)
For each staged file that touches a synced surface, maps the file to an entity, walks each layer (DB column → API field → admin form → public render → mobile schema), computes set-differences. Refuses the commit if any two layers disagree about a field.

### Sentinel 4 — Knowledge-Graph Refresh (post-commit)
Fires after every commit that touches mineable surfaces. Background-runs the KG miner. No-ops gracefully if the KG store isn't yet set up.

## The Autonomic Layer — five additional hooks

The Sentinels stop the wrong action. The autonomic layer surfaces the right context **before** any action. All five fail silent without configuration — you get value without setup, and more value as you customize `qa/entity-shapes.config.yaml`.

### Autonomic 1 — Ambient Impact (PreToolUse Read|Edit|Write|MultiEdit)
Tracks every file Read or Edited in the session. On the first Edit/Write inside a known entity's parity-layer fingerprint, emits a compact dossier of that entity's shape with the layers the AI hasn't touched yet flagged. Silent on subsequent edits to the same entity. Silent if no entity defined for the path. Override: `<PROJECT_SLUG>_SKIP_AMBIENT=1`.

### Autonomic 2 — Topic-Area Recall (UserPromptSubmit)
Word-matches the operator's prompt against known entity names. If an entity is mentioned, recalls recent diary entries + task observations about that area via the configured memory backend (mempalace | file | custom). Catches topic-switches the SessionStart inject misses. Override: `<PROJECT_SLUG>_SKIP_TOPIC_RECALL=1`.

### Autonomic 3 — Self-Stop Watchdog (PostToolUse Edit|Write|MultiEdit)
Two detectors over the session's edit log:
- **D1** — Edit on a file never Read this session ("current on-disk state may differ from your assumption")
- **D2** — ≥3 edits on the same file in the last 6 edit-class actions ("rapid-fire patching without verification")

Warn-only. Universally useful — doesn't require entity definitions. Override: `<PROJECT_SLUG>_SKIP_WATCHDOG=1`.

### Autonomic 4 — Correction-Learning (UserPromptSubmit)
Conservative regex detector for high-confidence operator corrections ("you missed", "from now on always", "don't ever", explicit "rule:"). On hit: captures a lesson into the memory backend tagged `correction` + branch + entities (derived from last-touched files). Future sessions in the same area auto-recall via the topic-area pathway. Override: `<PROJECT_SLUG>_SKIP_LEARN=1`.

### Autonomic 5 — Shape-Coverage Gate (pre-commit)
For each entity touched in the staged file set, checks whether the OTHER critical parity layers were also staged. Critical pairings come from `qa/entity-shapes.config.yaml`. Catches the iOS-Codable-mismatch / wire-spec-drift class. Warn-only by default; `--strict` to block. Override: `<PROJECT_SLUG>_SKIP_SHAPE_CHECK=1`.

## Memory backend selection

The autonomic layer's memory functions (recall, capture) dispatch via `lib-memory.sh`. Set `<PROJECT_SLUG>_MEMORY_BACKEND` to choose:

| Value | Behavior |
|---|---|
| `mempalace` *(default)* | Uses the canonical MemPalace MCP. Best signal — entities + drawers + diary all play together. |
| `file` | Writes lessons to `qa/.lessons/<date>.md`; recalls by grep. No MCP required. Portable. |
| `custom` | Sources `qa/.memory-custom.sh` for user-supplied implementations. Triggered by the `/exoskeleton-memory` companion skill. |
| `none` | Both recall and capture become no-ops. Use to disable memory entirely. |

If the consumer chose `custom` at install time, the orchestrator dispatches the companion `/exoskeleton-memory` skill at the end for second-stage wiring.

## Entity-shape registry — opt-in activation

`qa/entity-shapes.config.yaml` is shipped as a template with a worked example commented out. Without it customized, the resolver returns "no entity" for every file and the entity-aware hooks stay silent — only watchdog + correction-learning are active. To activate:

1. Open `qa/entity-shapes.config.yaml`, uncomment / customize the worked example for your project.
2. Run `python3 qa/mine-entity-shapes.py` — produces `qa/entity-shapes.json`.
3. Verify: `python3 qa/lib/entity_shapes.py --list` should print your entities.
4. From now on, editing a registered entity's file emits the ambient dossier on first touch.

Re-run the miner whenever you add or restructure an entity.

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

