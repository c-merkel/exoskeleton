---
name: exoskeleton-install
description: Orchestrator skill that bootstraps the full Exoskeleton stack (the AI exoskeleton from the Two Suits story) into a project. Coordinates six stage skills — Stage 0 system bootstrap (Docker, gh CLI, MCP servers, GitHub auth), then local environment, operating manual, the four guards, optional VPS — local first, production opt-in. Use when starting a new repo, onboarding AI to an existing repo, or setting up a fresh laptop from scratch. Companion to the Two Suits builder's guide.
---

# Exoskeleton — Install (Orchestrator)

This skill bootstraps the **Exoskeleton** stack — the working AI exoskeleton from the [*Two Suits* builder's guide](https://christianmerkel.com/two-suits/builders-guide) — into any project, on any machine. **Fresh-laptop friendly. Local first. VPS opt-in.**

## When to invoke

- A user says "set up the exoskeleton stack on this repo"
- A new project is being created and the user wants the stack scaffolded from day one
- A peer wants to share the pattern and needs a working starting point
- An existing project doesn't have a `CLAUDE.md` and the user is investing in AI-collaborator workflow
- **A fresh laptop with only Claude Code installed and nothing else** — the orchestrator covers this case by running Stage 0 (bootstrap) first

## The walkthrough — seven steps, two stages

When invoked, walk the user through these steps in order. Announce each step. Use TodoWrite to track progress.

### Step −1 — Mode selection (the FIRST thing you ask)

Before the probe, before any commands, the AI's very first message to the user is a warm welcome + this question:

> **Welcome! Before we start, one quick question so I can pace this right for you:**
>
> Have you set up a development environment before — installed Docker, used a terminal, all that?
>
> **A.** First time, or it's been a while. Walk me through every step.
> **B.** I've done this before. Move fast, less hand-holding.

The user's answer picks the pacing mode for the *entire* rest of this orchestrator AND any sub-skills it dispatches.

- **Answer A** → switch into **Concierge Mode**. Slow pace, one step at a time, plain-English preambles, reassurance, celebration at each win. Detailed rules in `exoskeleton-bootstrap/SKILL.md` § "Concierge Mode". The orchestrator inherits and passes this to every sub-skill via the dispatch prompt.
- **Answer B** → Express Mode. Compact pace, less narration. Skip preambles and celebrations. Still verify after each install.

Store this answer for the rest of the session. If the user later says "slow down" or "go faster," switch modes mid-flow.

### Step 0 — System probe + bootstrap handoff

Before touching the project, verify the user's machine has everything the stack will need. Run a fast probe — the canonical stack is opinionated, six MCP servers, all required:

```bash
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then echo "✓ docker"; else echo "✗ docker"; fi
if command -v git >/dev/null && git config --global user.email >/dev/null 2>&1; then echo "✓ git"; else echo "✗ git"; fi
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then echo "✓ gh authed"; else echo "✗ gh"; fi
if [ -f ~/.ssh/id_ed25519.pub ] || [ -f ~/.ssh/id_rsa.pub ]; then echo "✓ SSH key"; else echo "✗ SSH key"; fi

# Canonical MCP stack — three-state probe:
#   ✓ = installed AND command matches canonical fingerprint
#   ~ = installed BUT command differs (drift — fix via Phase 5b reconcile)
#   ✗ = missing (install via Phase 5)
#
# For each canonical server we check that the registered command contains a known fingerprint string.
# Browser automation is broad: direct playwright OR the MCP_DOCKER / claude-in-chrome alias paths.
mcp_check() {
  local srv="$1" fingerprint="$2"
  local line
  line=$(claude mcp list 2>/dev/null | grep -i "$srv" | head -1)
  if [ -z "$line" ]; then echo "✗ $srv (missing)"; return 1; fi
  if echo "$line" | grep -qiE "$fingerprint"; then echo "✓ $srv"; return 0; fi
  echo "~ $srv (drift — installed with non-canonical command)"; return 2
}

mcp_check "serena"     "oraios/serena|serena start-mcp-server"
mcp_check "jcodemunch" "jcodemunch"
mcp_check "jdocmunch"  "jdocmunch"
mcp_check "mempalace"  "mempalace"
if claude mcp list 2>/dev/null | grep -qE "playwright|MCP_DOCKER|claude-in-chrome"; then echo "✓ browser automation"; else echo "✗ browser automation"; fi
if claude mcp list 2>/dev/null | grep -qE "mariadb|postgres|sqlite"; then echo "✓ DB MCP"; else echo "✗ DB MCP"; fi
```

**Three handoff paths based on the probe rows:**

- **Any `✗` row (missing prerequisite):** invoke `/exoskeleton-bootstrap` to install. Bootstrap walks Phases 0–5: OS detection, Homebrew (macOS), Docker Desktop, gh CLI, jq, python3, GitHub auth + SSH key generation, then installs the missing canonical MCP servers. Verifies each install before moving on.

- **Any `~` row (drift — MCP installed but with non-canonical command):** invoke `/exoskeleton-bootstrap --reconcile` to enter Phase 5b. The reconcile flow inventories existing MCPs, diffs against the canonical fingerprints, asks the user in concierge mode before fixing each drift, and preserves any Foreign MCPs the user has for other projects. Critical for upgrade paths — without this, a stale Serena (or any other canonical MCP installed with an outdated command) would never get caught by a name-only probe.

- **Every row `✓`:** skip directly to Step 1. The machine is fully aligned with the canonical stack.

Bootstrap is honest about what requires user action — sudo passwords, GUI installers (Docker Desktop), browser auth (gh login) cannot be automated by the skill. It guides + verifies.

#### Returning to this orchestrator after bootstrap

**Important — after the bootstrap (or reconcile) finishes, control returns here.** The user does **not** need to re-invoke `/exoskeleton-install`. Continue automatically to Step 1 (Discover the project). In Concierge Mode, announce the transition with a celebratory line first — e.g.:

> *"Beautiful — your machine is fully equipped. Now let's set up your project itself. ☕"*

Then proceed to Step 1.

If the user's pacing mode was set in Step −1, it stays in effect for the remainder of this orchestrator and any further sub-skill dispatches (manual, guards, deploy).

### Step 1 — Discover the project

Run in parallel:
- `ls` the project root to see what's already there
- `cat README.md` or equivalent to learn what the project is
- `git log --oneline -5` to see recent commit style
- Check whether `.claude/`, `CLAUDE.md`, `.githooks/`, `docker-compose.yml` already exist

Tell the user what you found. **Never overwrite an existing file without explicit confirmation.**

### Step 2 — Ask the seven questions

Ask the user (one message with all seven, AskUserQuestion if available):

1. **Project name** (human-readable, e.g. "Acme Storefront")
2. **One-line description** of what the project does
3. **Your platform's layers** as a comma-separated list (e.g. "database, API, web admin, mobile app, public site"). Most platforms have 3–7.
4. **Primary database** — **MariaDB 11 by default** (matches the reference stack). Postgres / SQLite accepted; the skill defaults to MariaDB if the user has no preference.
5. **Code stack** (e.g. "Rails + React + Swift", "Django + Vue", "Go + Next.js")
6. **Largest available Claude model** (Architect tier) — usually whichever Opus-class model the user has access to
7. **Medium-tier Claude model** (Executor / specialist tier) — usually whichever Sonnet-class model

Confirm the answers back to the user before generating.

### Step 3 — Confirm the plan

Show the user the plan in plain English:
- Which files will be created
- Which files will be modified (if any)
- Which existing files will be untouched
- That VPS setup is **not** part of this run — that's a separate skill (`/exoskeleton-deploy`)

Wait for the user to say go.

### Step 4 — Invoke `/exoskeleton-local`

Dispatch the local-environment skill. It:
- Creates `docker-compose.yml` and `start.sh`
- Creates `.claude/settings.json` with hook wiring + permissions
- Lists the MCP servers the user needs to install (with install commands)
- Prints what's expected to be running before continuing

If the local skill fails or asks for input, surface that to the user before continuing.

### Step 5 — Invoke `/exoskeleton-manual` and `/exoskeleton-guards`

These can run in parallel (no shared files):

- `/exoskeleton-manual` — writes `CLAUDE.md`, agent definitions in `.claude/agents/`, slash commands in `.claude/commands/`
- `/exoskeleton-guards` — writes the four hooks in `.claude/hooks/` and the parity gate in `.githooks/pre-commit`

### Step 6 — Verify

Invoke `/verify-stack` (one of the slash commands installed in Step 5). It runs a 12-check health pass:

1. Docker stack starts cleanly
2. Live preview reachable on the local URL
3. CLAUDE.md exists and is non-trivial
4. Four Sentinel scripts exist and pass `bash -n` syntax check
5. Five autonomic-layer hook scripts exist and pass `bash -n` syntax check (ambient-impact, recall-topic-area, self-stop-watchdog, learn-from-correction, lib-session + lib-memory libs sourceable)
6. `qa/lib/entity_shapes.py` is importable (`python3 -c 'from qa.lib.entity_shapes import resolve_entity_for_path'`)
7. `qa/check-shape-coverage.py` runs against an empty stdin without error
8. `qa/mine-entity-shapes.py` runs (with no config → produces dormant shapes file)
9. Pre-commit hook is wired (`core.hooksPath`)
10. Agent definitions parse as valid markdown
11. Slash commands are registered
12. MCP servers respond to a status check (including MemPalace if `<PROJECT_SLUG>_MEMORY_BACKEND=mempalace`)

Report green/yellow/red with one specific next action per failure.

### Step 6.5 — Memory backend dispatch (conditional)

If the operator chose `custom` for memory backend in the guards step, dispatch `/exoskeleton-memory` here as the second-stage installer. That skill walks them through wiring `qa/.memory-custom.sh` with their preferred memory provider. Skip this step for `mempalace` or `file`.

## VPS deployment is separate

Do not run `/exoskeleton-deploy` from this orchestrator. The local stack stands on its own. The VPS skill is opt-in, asks for credentials, and runs only when the user explicitly invokes it after local is green.

Tell the user, when the orchestrator finishes:

> Your local stack is up. To deploy this to a production server, invoke `/exoskeleton-deploy` — that skill walks the VPS setup separately, asks for SSH credentials, and explains the production topology before doing anything destructive.

## Hard rules for this skill

1. **Never overwrite an existing file without explicit confirmation.** If `CLAUDE.md` already exists, ask whether to merge, replace, or skip.
2. **Local before production, always.** Never invoke `/exoskeleton-deploy` from this orchestrator.
3. **No credentials handling.** This skill never reads or writes SSH keys, API tokens, or `.env` files with secrets. The VPS skill handles its own credential prompts.
4. **One transactional commit at the end.** When all four stages succeed, commit the new files as a single logical commit: `feat(stack): bootstrap two-suits operator-architect stack`. Do not push without the user's go-ahead.
5. **If any stage fails, stop.** Surface the failure. Do not retry silently. Do not paper over with mocks.

## Placeholders the stages will fill in

| Placeholder | Source | Example value |
|---|---|---|
| `<PROJECT_NAME>` | Q1 | `Acme Storefront` |
| `<PROJECT_SLUG>` | Q1 (kebab-case) | `acme-storefront` |
| `<PROJECT_DESCRIPTION>` | Q2 | `Inventory + ordering for small retailers.` |
| `<LAYERS_LIST>` | Q3 | `database, API, web admin, mobile app, public site` |
| `<LAYERS_COUNT>` | Q3 (derived) | `5` |
| `<PRIMARY_DB>` | Q4 | `MariaDB 11` |
| `<CODE_STACK>` | Q5 | `Rails + React + Swift` |
| `<ARCHITECT_MODEL>` | Q6 | `the largest available Claude model` |
| `<EXECUTOR_MODEL>` | Q7 | `the medium-tier Claude model` |

If a placeholder doesn't apply (e.g., the user has no mobile app), drop the corresponding layer cleanly rather than leaving a placeholder in the output.

## After the bootstrap

Tell the user where to go next:
- Open the project in Claude Code, the operating manual will load on every session
- Read the [builder's guide](https://christianmerkel.com/two-suits/builders-guide) for the architectural reasoning behind each piece
- Iterate the parity-check script as their schema stabilizes
- Invoke `/learn` (one of the installed slash commands) when a bug takes more than 30 minutes to find — the skill converts the bug into a KnownBug entity and prompts the user to write the corresponding rule

