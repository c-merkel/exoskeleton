---
name: exoskeleton-local
description: Stage skill that gets the Exoskeleton local development environment running. Creates docker-compose.yml mirroring a production topology, a one-command start.sh, .claude/settings.json with hook wiring and permissions, and prints the list of MCP servers to install. Always runs before VPS deployment.
---

# Exoskeleton — Local Environment

This skill gets a working local environment running that mirrors what production will look like.

## When to invoke

- Called by `/exoskeleton-install` as the first stage
- Or invoked standalone if the user already has CLAUDE.md and just wants the Docker stack + Claude Code settings

## What this skill creates

```
<project-root>/
├── docker-compose.yml              ← web + db + reverse-proxy
├── start.sh                        ← one-command bring-up + prereq check
└── .claude/
    └── settings.json               ← hook wiring + permissions + MCP server list
```

## Walkthrough

### Step 1 — Read answers from the orchestrator

If invoked standalone, ask the user:
- Primary database (**MariaDB** is the default — Postgres / SQLite / other accepted)
- Web framework / language
- Whether they want a reverse proxy with auto-TLS for the local cert (Caddy is the default)

If invoked by `/exoskeleton-install`, read the answers from the user's prior responses in this conversation.

### Step 2 — Write `docker-compose.yml`

Use the template at `templates/docker-compose.yml.template` in this skill folder. The template ships with three services:
- `web` — placeholder image, mount the project source as a volume
- `db` — the user's chosen database engine
- `proxy` — Caddy for auto-TLS in local dev

Replace placeholders with the user's answers. Do not include any secrets in the file. Environment variables that need secrets go through `.env` (gitignored).

### Step 3 — Write `start.sh`

A small bash script:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Verify Docker is running
docker info > /dev/null 2>&1 || { echo "Docker is not running. Start it and retry."; exit 1; }

# 2. Verify Compose is available
docker compose version > /dev/null 2>&1 || { echo "docker compose not found."; exit 1; }

# 3. Bring up the stack
docker compose up -d

# 4. Wait for health
echo "Waiting for stack to come up..."
sleep 3

# 5. Print URLs
echo ""
echo "Stack running:"
echo "  Web:    http://localhost:8080"
echo "  Admin:  http://localhost:8080/admin"
echo "  DB:     localhost:5432"
echo ""
echo "If anything is red above, fix it before continuing."
```

Make it executable: `chmod +x start.sh`.

### Step 4 — Write `.claude/settings.json`

Use the template at `templates/settings.json.template`. The template wires:
- The four Sentinel hooks (placeholders — actual scripts are installed by `/exoskeleton-guards`)
- Sensible default permissions (allow `git`, `docker`, `npm`, `mkdir`, etc.; deny `rm -rf`, `git push --force`, etc.)
- MCP server placeholders for the user's stack

### Step 5 — Verify the canonical MCP stack is installed

By the time this skill runs, `/exoskeleton-bootstrap` should have already installed the canonical six-server stack. Verify all six are reachable before continuing:

```bash
claude mcp list
```

Required (all six — the stack is opinionated, not configurable):

1. **Serena** — symbol-level code intel via LSP
2. **jCodeMunch** — repo-scale code intel (blast radius, dead code, dep graphs)
3. **jDocMunch** — section-level doc retrieval
4. **MemPalace** — knowledge graph + memory drawers
5. **Live DB MCP** — matched to `<PRIMARY_DB>`: **mariadb** (default) / postgres / sqlite
6. **Playwright** — browser automation

If any are missing, invoke `/exoskeleton-bootstrap` (Phase 5) and complete that before continuing. **Do not paper over a missing MCP.** The exoskeleton's discipline (Pre-Change Protocol, parity check, cross-session memory) depends on the canonical six. Substituting tools breaks the protocol's assumptions.

### Step 6 — Run `./start.sh` and verify

Run the start script. If it succeeds, the local stack is up. If it fails, surface the exact error and stop. Do not move forward — this is the foundation everything else depends on.

## Hard rules

1. **No secrets in committed files.** `.env` and any file with credentials goes in `.gitignore`. Always check.
2. **Local stack must mirror production shape.** If production runs MariaDB, local runs MariaDB (not SQLite). Same database engine, same web server, same OS base. The canonical default is MariaDB to match the reference stack.
3. **Idempotent.** Re-running this skill on the same project should not break anything — it should check what's already there and only create what's missing.
4. **No `start-local.sh` magic.** The script names every prereq it expects. If something's missing, it says so in English and exits cleanly. It never auto-installs anything.

## Output the user should see

When this skill completes, tell the user:

> Local stack is up at http://localhost:8080.
>
> Next: invoke `/exoskeleton-manual` and `/exoskeleton-guards` (the orchestrator will do this automatically). When all four hooks are installed, run `/verify-stack` to confirm everything's green.
