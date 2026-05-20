---
name: exoskeleton-memory
description: Second-stage installer for the autonomic-layer memory backend when the operator chose "bring your own" at install time. Walks the operator through wiring a custom memory provider via qa/.memory-custom.sh. Use only when /exoskeleton-install's guards stage set <PROJECT_SLUG>_MEMORY_BACKEND=custom. Skip otherwise — file and mempalace backends are self-contained.
---

# Exoskeleton — Bring-Your-Own Memory (second stage)

The autonomic layer's two memory-using hooks (`recall-topic-area.sh`, `learn-from-correction.sh`) dispatch via `lib-memory.sh`. The library supports three out-of-the-box backends:

| Backend | Status | When to pick |
|---|---|---|
| `mempalace` | Default, canonical | You ran `/exoskeleton-bootstrap` and have the MemPalace MCP installed. Best signal — entities + drawers + diary unified. |
| `file` | Self-contained fallback | You don't want any MCP for memory. Lessons land in `qa/.lessons/<date>.md`. Portable. |
| `custom` | This skill wires it | You have your own memory provider (Linear, Notion, GitHub Issues, an internal MCP, a Slack channel — anything with a CLI). |

This skill runs when the operator picked **custom**.

## When to invoke

- The `/exoskeleton-install` orchestrator dispatched here automatically because the guards stage set `<PROJECT_SLUG>_MEMORY_BACKEND=custom` in `.claude/settings.json`.
- Or invoked standalone by an operator who wants to switch an existing project from `mempalace` / `file` to `custom`.

## Contract — what your `qa/.memory-custom.sh` must do

`lib-memory.sh` dispatches into a single executable at `qa/.memory-custom.sh`. The path can be overridden by `<PROJECT_SLUG>_MEMORY_CUSTOM` env var.

The script is invoked with one of two subcommands. It must print to stdout on success and exit 0 on either success or no-op. Errors should exit non-zero and print to stderr.

### Subcommand: `recall <entity-name> <days-back>`

```
$ qa/.memory-custom.sh recall "Customer" 14
- 2026-05-19: Customer wire-spec drift caught in pre-commit; iOS Codable needed a doc update.
- 2026-05-17: New customer.preferred_contact_method field added; mobile picked up on next sync.
```

Output format: markdown bullet lines, `- <date>: <one-line snippet>`. Up to 2 lines per call. Empty stdout = no relevant memory.

### Subcommand: `capture <doc> <tags-csv> <branch> <entities-csv>`

```
$ qa/.memory-custom.sh capture "CORRECTION: don't forget the iOS Codable when changing CustomerSyncService" "correction" "main" "customer"
```

The script persists the lesson somewhere your team will see it (Linear comment, Notion page, Slack message, MCP write, whatever). Idempotent — same doc twice in one day should not duplicate.

## Walkthrough

### Step 1 — Confirm the setting is in place

```bash
grep MEMORY_BACKEND .claude/settings.json
# Expected: "<PROJECT_SLUG>_MEMORY_BACKEND": "custom"
```

If not present, the orchestrator was wrong to dispatch here — write the value, then continue.

### Step 2 — Discover the provider

Ask the operator:

> *Where should lessons + recall go? Tell me what tool / system you'd like to use. Common picks:*
> *  - Linear (project comments via gh-like CLI)*
> *  - Notion (page or database)*
> *  - GitHub Issues (one issue per project, lessons as comments)*
> *  - Slack (a dedicated channel, posted via webhook)*
> *  - Self-hosted (your own MCP server / API)*
> *  - Another MemPalace instance (e.g. team-shared)*

Wait for the answer.

### Step 3 — Scaffold the script

Create `qa/.memory-custom.sh` (executable, not committed if it contains credentials):

```bash
#!/usr/bin/env bash
# Custom memory backend for <PROJECT_NAME>.
# Invoked by lib-memory.sh dispatcher.
set -euo pipefail

SUBCMD="${1:-}"; shift || true

case "$SUBCMD" in
  recall)
    ENTITY="${1:-}"; DAYS="${2:-14}"
    # TODO: implement recall — print markdown bullets, exit 0
    ;;
  capture)
    DOC="${1:-}"; TAGS="${2:-}"; BRANCH="${3:-}"; ENTITIES="${4:-}"
    # TODO: implement capture — persist to your provider, exit 0
    ;;
  *)
    echo "usage: $0 {recall|capture} ..." >&2
    exit 1
    ;;
esac
```

Fill in the TODOs based on the provider. Show the operator the empty scaffold; offer to fill the calls if you know the provider's CLI (e.g. `gh issue comment`, `slack-cli post`, `curl` to a webhook).

### Step 4 — Credentials hygiene

Before any provider call is wired in, remind the operator:

- **Never inline a token in `qa/.memory-custom.sh`.** Read from env (`$LINEAR_TOKEN`, `$SLACK_WEBHOOK_URL`, etc.) or a gitignored config file.
- Add `qa/.memory-custom.sh` to `.gitignore` if the script itself contains anything sensitive. Most should not — credentials live in env, not the script.
- The exoskeleton repo has zero awareness of operator credentials. This skill never reads or writes secrets.

### Step 5 — Smoke test

```bash
# recall — should print 0 or 1-2 lines, exit 0
qa/.memory-custom.sh recall "any-known-entity" 14

# capture — should persist somewhere, exit 0
qa/.memory-custom.sh capture "smoke test: ignore" "test" "main" ""
```

Then verify via the autonomic hook:

```bash
# Triggers correction-learning → custom capture
echo '{"prompt":"rule: smoke test for custom memory backend","session_id":"smoke"}' | .claude/hooks/learn-from-correction.sh
```

The operator should see the smoke entry in their provider.

### Step 6 — Clean up smoke entries

Tell the operator to delete the smoke entries from their provider (Linear comment, Notion page, etc.).

## Hard rules

1. **No secrets in the committed script.** Env vars or gitignored config files only.
2. **Both subcommands must be idempotent within a single day.** Capture twice with identical input = one record.
3. **Both subcommands must exit 0 on success AND on no-op.** Errors raise non-zero with a message to stderr — the autonomic hooks fail-soft so a broken backend never blocks an edit or prompt.
4. **Recall output is markdown bullets.** Anything else corrupts the additionalContext envelope.
5. **The provider must persist.** Don't wire to anything ephemeral (in-memory store, /tmp file). The whole point is cross-session memory.

## Output the operator should see when this skill completes

> Custom memory backend wired at `qa/.memory-custom.sh`.
> Provider: <PROVIDER_NAME>
> Smoke tests passed (recall + capture round-tripped).
>
> The autonomic layer's recall + correction-learning hooks now flow through your provider. To switch back to MemPalace or file-based memory, set `<PROJECT_SLUG>_MEMORY_BACKEND` to `mempalace` or `file` in `.claude/settings.json`.
