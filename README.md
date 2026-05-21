# exoskeleton

A bundle of eight Claude Code skills that bootstrap the **Operator-Architect multi-agent stack** from the [*Two Suits* builder's guide](https://christianmerkel.com/two-suits/builders-guide) into any project, local-first, in about ten minutes — and a continuous upstream channel for consumer improvements to flow back into the public bundle.

The article *Two Suits* tells the story. **The exoskeleton is what does the work.** This is the exoskeleton.

![The Two Suits — the cinematic universe the exoskeleton comes from](assets/hero.png)

## What's in the bundle

Nine skills. Each invocable standalone. One orchestrator runs the core six in sequence; the others are conditional installers + the upstream-promotion channel + the iOS / mobile programmatic-debuggability layer.

```
.claude/skills/exoskeleton/
├── README.md                          ← you are here
├── exoskeleton-install/               ← orchestrator (run this first)
├── exoskeleton-bootstrap/             ← Stage 0 — fresh-laptop setup (Docker, gh, MCP servers, GitHub auth)
├── exoskeleton-local/                 ← Docker compose + project-specific MCP wiring
├── exoskeleton-manual/                ← generates CLAUDE.md, agents, slash commands
├── exoskeleton-guards/                ← installs four non-AI guards + five-layer autonomic sensing harness
├── exoskeleton-memory/                ← second-stage installer for custom memory backends (BYO)
├── exoskeleton-deploy/                ← VPS deployment wizard (after local is green)
├── exoskeleton-promote/               ← upstream channel — periodic consumer→bundle improvement lift
└── exoskeleton-mobile-ax/             ← iOS / SwiftUI programmatic-debuggability layer (auto-surfaces on iOS work)
```

### Mobile AX layer (iOS / SwiftUI consumers)

If your project includes a SwiftUI app, the `exoskeleton-mobile-ax` skill installs a canonical accessibility-identifier + diagnostic-trace layer so the agent's QA harness can drive every flow programmatically — no coordinate guessing, no screenshot loops, no ~30K-token-per-shot drag. Every new view picks up a 4-point checklist (`.ax(...)`, `Trace.viewAppear`, `Trace.action`, `Trace.formSubmit`); a PreToolUse nudge hook reminds on Edit/Write of view files; a coverage tracker keeps the ledger honest. Real VoiceOver users benefit too — `.ax(_:)` sets identifier AND label from one call. Templates at `templates/mobile-ax/`, hook at `templates/hooks/nudge-mobile-ax-on-view-edit.sh`.

The promote skill closes the loop: improvements you make in your consumer project (a tighter detector, a new entity-shape pattern, a better correction-pattern regex) get inventoried, classified, and lifted back to the public bundle as a transactional PR. The exoskeleton learns from every consumer that uses it.

### Two layers of protection

The guards skill installs **two complementary layers** that work together:

- **Four Sentinels** *(stop the wrong thing)* — Pre-Change Protocol Hook, Schema-Verify, pre-commit Parity Check, post-commit KG Refresh. Non-AI guards that refuse destructive actions when prerequisites aren't met.
- **Autonomic sensing harness** *(surface the right context)* — Ambient Impact (peripheral vision on first edit), Topic-Area Recall (deep memory on prompt), Self-Stop Watchdog (D1 edit-without-read + D2 rapid-fire detector), Correction-Learning (lessons captured to memory), Shape-Coverage Gate (pre-commit parity warning). Fail-silent without configuration — universally useful detectors active out of the box, entity-aware power-ups unlock when you customize `qa/entity-shapes.config.yaml`.

The Sentinels never let you do the wrong thing. The autonomic layer makes sure you know the right thing before you start.

The orchestrator probes the machine first — a **three-state check** on every prerequisite and every MCP server:

- **✓** — present and matches the canonical setup
- **~** — present but *drifted*: an MCP installed with a stale or non-canonical command
- **✗** — missing

The probe state decides the handoff:

- **All ✓** — skip Stage 0, go straight to project setup.
- **Any ✗** — run Stage 0 (`exoskeleton-bootstrap`) to install the missing pieces.
- **Any ~** — run Stage 0 in `--reconcile` mode (Phase 5b) to fix the drift, asking before changing each server and leaving unrelated MCPs untouched.

A name-only probe would miss drift entirely — a stale Serena reads as "installed" and quietly breaks the protocol. The three-state probe catches it.

## What the exoskeleton produces

When the orchestrator finishes, you have:

- A `docker-compose.yml` that mirrors a production topology
- A `start.sh` one-command bootstrap
- A `CLAUDE.md` operating manual filled in with your project's specifics
- A `.claude/settings.json` wired to all hooks and the right permissions
- **Four guard scripts** (`.claude/hooks/`) — the Sentinels
- **Five autonomic-layer hooks** (`.claude/hooks/`) — ambient-impact, recall-topic-area, self-stop-watchdog, learn-from-correction, plus shared libs lib-session + lib-memory
- **Entity-shape registry** (`qa/lib/entity_shapes.py`, `qa/check-shape-coverage.py`, `qa/mine-entity-shapes.py`, `qa/entity-shapes.config.yaml.template`) — opt-in entity-aware peripheral vision
- A pluggable memory backend (`mempalace` default, `file` fallback, `custom` via `/exoskeleton-memory`)
- Three agent definitions (`.claude/agents/`)
- Three slash commands (`.claude/commands/`)
- A `parity-check.sh.template` you customize for your layers
- A `/verify-stack` slash command that confirms it all works
- (optional) a VPS deployment topology in `bin/vps/` if you ran `/exoskeleton-deploy`

![The operator-architect stack the exoskeleton installs](assets/architecture.png)

## Built with the exoskeleton

The bundle is the generalized form of a stack that already runs a real business — **Fefi Magical Moments**: a public booking site, a PHP/MariaDB admin backend, and a native iOS app, all built and operated with the operator-architect stack the exoskeleton scaffolds.

![Fefi Magical Moments — public site, web admin, and native iOS app](assets/built-with-it.png)

Not a demo — it takes real bookings, signs real waivers, processes real payments. The exoskeleton packages that same stack so you can put it on your own project.

## How to install the exoskeleton into your project

### Claude Code

```bash
# From your project's root directory, clone the bundle into the skills folder:
git clone https://github.com/c-merkel/exoskeleton.git .claude/skills/exoskeleton

# Open the project in Claude Code:
claude

# Invoke the orchestrator — it walks the whole install for you, station by station:
> /exoskeleton-install
```

### Codex CLI (OpenAI)

The Agent Skills format became an open standard in late 2025 — Codex CLI loads skills from the same `SKILL.md` files. Install path:

```bash
# From your project's root directory, clone the bundle into the skills folder:
git clone https://github.com/c-merkel/exoskeleton.git .codex/skills/exoskeleton

# Open the project in Codex CLI:
codex

# Invoke the orchestrator — it walks the whole install for you, station by station:
> /exoskeleton-install
```

If Codex stores skills in a different default path on your machine, check `codex skills path` (or the equivalent for your version) and clone there instead. The skill behavior is identical across both AIs — same prompts, same outputs.

### Either AI

The bundle is dual-target: the `SKILL.md` files contain no Claude-Code-specific syntax. The hooks under `templates/hooks/` are bash + python and OS-portable. The only AI-specific surface is the sub-agent definitions under `templates/agents/`, which assume Claude's `Task` tool naming — Codex users may need to swap `Task → spawn_agent` (or the Codex equivalent) when invoking them.

## The first thing it asks: your pace

Before any probe or command, the orchestrator asks one question — have you set up a development environment before? Your answer sets the pace for the entire run:

- **Concierge Mode** — first-timers. One command at a time, a plain-English preamble before each, every line of terminal output translated, a small celebration at each win. Built for the creative-side-of-the-business user who has never opened a terminal.
- **Express Mode** — experienced users. One message per phase, all commands at once, no preamble. Pace, not silence — you still get a fix recommendation when something fails.

Say "slow down" or "go faster" at any point to switch. The chosen pace carries into every sub-skill the orchestrator dispatches.

## Local-first by design

The orchestrator gets a working local environment running **before** asking about VPS credentials. You can stop after `/exoskeleton-local` and never deploy to a server — the local stack stands on its own. The `/exoskeleton-deploy` skill is opt-in, runs last, and asks for explicit credentials.

## Invoking sub-skills individually

You don't have to run the orchestrator. Each sub-skill is a slash command:

```
/exoskeleton-bootstrap     # Stage 0 — fresh-laptop setup (Docker, gh, MCP, GitHub auth)
/exoskeleton-local         # local Docker + project-specific MCP wiring
/exoskeleton-manual        # generates the operating manual
/exoskeleton-guards        # installs the four Sentinels + the autonomic sensing harness
/exoskeleton-memory        # second-stage installer when you picked "bring your own" memory backend
/exoskeleton-deploy        # VPS deployment wizard
/exoskeleton-promote       # periodic upstream lift — consumer improvements → public bundle
```

Useful when re-running a single stage after a config change, or when you already have parts of the stack and only need to fill in one piece.

`exoskeleton-bootstrap` also takes two flags for the upgrade path:

- `/exoskeleton-bootstrap --reconcile` — skip straight to MCP reconciliation (Phase 5b). Diffs your installed MCP servers against the canonical set, asks before fixing each drifted one, and preserves servers you use for other projects. This is what the orchestrator's probe invokes when it sees a `~` row.
- `/exoskeleton-bootstrap --clean` — remove the canonical MCP servers and reinstall them from scratch. Destructive; use only when you explicitly want a clean slate.

## Each station offers three modes

The builder's guide is organized into ten stations. At every station, you can:

1. **Run the skill** — invoke `/exoskeleton-<station>` and the bundle does it for you. You read along to learn what happened.
2. **Use a prompt** — copy the prompt block, paste it into your own Claude (or any AI), and let your AI do the work with your adjustments.
3. **Do it manually** — type every command and write every file yourself.

All three end at the same place. The skill mode is the fastest; the manual mode is the most instructive. Pick the one that fits your moment.

## Prerequisites

- Claude Code installed (`claude.com/claude-code`)
- Docker Desktop (or compatible) for the local stack
- `git` configured with the project repo
- About 10 minutes for the local install, another 15–20 for VPS

## Platform support

The four guards and the git hooks are written in `bash` + `python3`. Specifically:

- **macOS** — fully supported. This is the platform the bundle was built and tested on.
- **Linux** — fully supported. Templates use the GNU-flavored utilities (`sed -i 's/.../.../'`, `grep -P`, etc.) that ship with every mainstream distro.
- **Windows (native PowerShell/cmd)** — not supported. The hooks are bash scripts, and git hooks invoked via `core.hooksPath` don't translate cleanly to native Windows shells.
- **Windows via WSL2** — fully supported. Claude Code on Windows is documented to run inside WSL2 anyway; inside that environment the bundle behaves exactly like Linux. Docker Desktop bridges to the WSL2 backend transparently.

If you're on Windows and not already using WSL2, install it first (`wsl --install`) and run Claude Code from the WSL2 shell. The exoskeleton bundle has no native-Windows codepath and there is no plan to add one — WSL2 is the supported answer.

## Companion reading

The full Two Suits universe lives at [**christianmerkel.com/two-suits**](https://christianmerkel.com/two-suits) — the **Information Hub** that links to every piece below in one place.

- **Two Suits — Information Hub:** [christianmerkel.com/two-suits](https://christianmerkel.com/two-suits) — the landing page; pick your door from there.
- **Start Here:** [the friendly walkthrough](https://christianmerkel.com/two-suits/start-here) — fit your own exoskeleton in 11 stages, about 30 minutes, no jargon.
- **The Showcase:** [see what it built](https://christianmerkel.com/two-suits/showcase) — a real production business in 16 screenshots: public site, web admin, native iOS.
- **The Story:** [*Two Suits*](https://christianmerkel.com/two-suits/story) — first-person narrative of the build.
- **The Builder's Guide:** [*Two Suits — Builder's Guide*](https://christianmerkel.com/two-suits/builders-guide) — the architecture as a map; 11 stations, 3 modes each.
- **The Graphic Novel:** [*Two Suits — The Graphic Novel*](https://christianmerkel.com/two-suits/comic) — the painterly cinematic companion.

---

Stack-agnostic. The bundle works for any language, any framework, any database — you provide the stack-specific bits in the prompts. The patterns ship in the templates; the implementation is yours.

