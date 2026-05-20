---
description: Plan a non-trivial change before writing code. Dispatches the Architect sub-agent for analysis, then waits for operator sign-off before dispatching the Executor.
allowed-tools: Task, Read, Grep, Glob, Bash
---

# /plan

You are about to plan a non-trivial change for: **$ARGUMENTS**

Three-phase protocol:

## Phase 1 — Architect (planning only, no code writes)

Dispatch the `architect` sub-agent with the request. The Architect produces a structured plan:

- **Mission** — one-line summary of what we're changing
- **Layers touched** — DB / API / admin / mobile / public — any layer the change visits
- **Order of changes** — usually DB → API → admin → public → mobile
- **Acceptance criteria** — what does "done" look like, measurable
- **Verification plan** — how do we know it works (tests, smoke checks, manual flows)
- **Commit message** — proposed imperative subject for the eventual commit
- **Risks / unknowns** — what could break, what we don't know

The Architect must not write code. If the request is small enough to skip planning, it says so and recommends going direct.

## Phase 2 — Operator sign-off

After the Architect returns its plan, **stop and present the plan to the operator**. Wait for explicit "go" or revisions before continuing.

Do not invoke the Executor automatically. The operator approves the plan first.

## Phase 3 — Executor (implementation)

Once the operator approves, dispatch the `executor` sub-agent with the approved plan attached verbatim. The Executor:

1. Implements the plan literally — no scope creep
2. Runs the verification steps the Architect specified
3. Creates a small logical commit with the proposed message
4. Reports back what changed (file paths + one-line diff summary)

## Hard rules

- **Architect never writes code.** Plans only.
- **Executor never re-plans.** It executes the approved plan literally.
- **Operator signs off in between.** No auto-progression from Phase 1 to Phase 3.
- **If the change is trivial** (typo fix, single-line update), skip the protocol — just do it.

