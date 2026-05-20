---
name: exoskeleton-manual
description: Stage skill that generates the project's CLAUDE.md operating manual from the user's seven answers (project name, layers, primary DB, code stack, models). Also installs three agent definitions (architect, executor, researcher) and three slash commands (/plan, /verify-stack, /learn). Use after the local environment is up.
---

# Exoskeleton — Operating Manual

Generates the `CLAUDE.md` operating manual the AI will load on every session, plus the supporting agent definitions and slash commands.

## When to invoke

- Called by `/exoskeleton-install` as the second stage
- Or invoked standalone when the user already has a local environment and just wants the AI side wired up

## What this skill creates

```
<project-root>/
├── CLAUDE.md                       ← the operating manual (loads every session)
└── .claude/
    ├── agents/
    │   ├── architect.md            ← planner contract (largest model)
    │   ├── executor.md             ← implementer contract (medium-tier)
    │   └── researcher.md           ← read-only research contract
    └── commands/
        ├── plan.md                 ← /plan — invoke Architect explicitly
        ├── verify-stack.md         ← /verify-stack — 8-check health pass
        └── learn.md                ← /learn — bug → rule → hook capture
```

## Walkthrough

### Step 1 — Read the seven answers

Either from the prior orchestrator conversation, or by asking the user if invoked standalone.

### Step 2 — Generate `CLAUDE.md`

Use the template at `templates/CLAUDE.md.template`. The template has these sections:

- **What this project is** (filled from Q1 + Q2)
- **Mandatory workflows** — Pre-Change Protocol, Tool Selection Protocol, source-of-truth precedence
- **Tool stack** — the user's specific MCP servers (filled from the install)
- **The four Sentinels** — names, what each catches, override flags
- **Sub-agent tier table** — which agent for which surface (filled from Q3 + Q5)
- **Commit autonomy rules** — what Claude can do without asking, what requires explicit OK
- **Database changes** — one-off vs migration, prod-safe rules
- **Working agreement** — fix forward, test rigorously, small commits

Replace placeholders. Use the user's actual layer names. If they have fewer than 5 layers, drop the unused references.

**Length target: under 500 lines.** If the generated CLAUDE.md is longer, trim — load-bearing only. Facts that change live in the knowledge graph (the next skill installs the SessionStart hook for that).

### Step 3 — Generate three agent definitions

Use the templates at `templates/agents/`. Each agent gets:

- A frontmatter block with `name`, `description`, `model`, `tools`
- A role definition (what it does, what it doesn't)
- Hard rules (the things it can never violate)
- Escalation paths (when to ask the operator)

The three agents:

- **`architect.md`** — uses `<ARCHITECT_MODEL>`. Plans. Never writes code. Produces a precise plan (Mission / Layers / Order / Acceptance / Verification / Commit msg / Open questions) and waits for the operator's signature.
- **`executor.md`** — uses `<EXECUTOR_MODEL>`. Implements the plan literally. Full git autonomy (commit + push) but never invents scope. Refuses cross-layer scope creep.
- **`researcher.md`** — uses `<EXECUTOR_MODEL>`. Read-only. Explicit allowed/forbidden tool lists. SELECT-only DB access. 400-word default response cap.

### Step 4 — Generate three slash commands

Use the templates at `templates/commands/`:

- **`/plan <description>`** — dispatches the Architect with the description. When the Architect produces a plan, prompts the operator for sign-off. On approval, dispatches the Executor with the approved plan.
- **`/verify-stack`** — runs the 8-check health pass (Docker, live preview, CLAUDE.md, Sentinel scripts, pre-commit wiring, agents, commands, MCP servers). Reports green/yellow/red with one specific action per failure.
- **`/learn`** — three-tier bug capture: first sighting → KnownBug entity in the KG; second sighting → write a Rule into CLAUDE.md; third sighting → write a Sentinel hook. Hard rule: no skipping tiers.

### Step 5 — Verify everything parses

Quick sanity check before declaring done:
- `head -5 CLAUDE.md` — should show the project name from Q1
- `ls .claude/agents/*.md` — three files
- `ls .claude/commands/*.md` — three files
- All `.md` files start with valid YAML frontmatter

## Hard rules

1. **Never write generic placeholders into final output.** Every `<PLACEHOLDER>` must be replaced with the user's actual value, or the section must be dropped cleanly.
2. **No fabricated tool names or model versions.** If the user said "use whatever Opus-class model is available," write that — not a specific version that may not exist next quarter.
3. **One CLAUDE.md, not several.** If a CLAUDE.md already exists, ask whether to merge, replace, or skip. Default to skip.
4. **Front-matter compliance.** Every `.md` file must have valid YAML frontmatter that Claude Code can parse. Test with `yq` or a similar parser if available.

## Output the user should see

When this skill completes:

> Operating manual written to `CLAUDE.md` (lines: NNN).
> Three agent definitions in `.claude/agents/`.
> Three slash commands in `.claude/commands/`.
>
> Next: `/exoskeleton-guards` installs the four guards and the pre-commit parity gate.

