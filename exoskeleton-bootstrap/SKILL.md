---
name: exoskeleton-bootstrap
description: Stage 0 — bootstraps a fresh laptop into a working AI development environment before any project setup happens. Detects OS, installs the missing prerequisites (Homebrew, Docker Desktop, git, gh CLI, jq, python3), walks the user through GitHub auth + SSH key + Anthropic API key, and finishes with every MCP server installed and reachable. Always runs FIRST when invoked by /exoskeleton-install. Skippable if the user already has a working dev environment.
---

# Exoskeleton — Bootstrap (Stage 0)

This skill turns a **fresh laptop** into a working AI-development environment. It runs before any project setup. The orchestrator (`/exoskeleton-install`) calls this first and skips to Stage 1 only when the system probe comes back fully green.

This skill is **honest about its limits.** It cannot type your sudo password, click through a Docker Desktop installer GUI, or sign you into GitHub on your behalf. It guides you through those steps and verifies each one before moving on.

## Mode selection — the FIRST thing you ask the user

Before *anything else* (yes, before the system probe), the AI's very first message to the user must be a warm welcome + this question:

> **Welcome! Before we start, one quick question so I can pace this right for you:**
>
> Have you set up a development environment before — installed Docker, used a terminal, all that?
>
> **A.** First time, or it's been a while. Walk me through every step.
> **B.** I've done this before. Move fast, less hand-holding.

The user's answer picks the pacing mode for the *entire* rest of this skill.

### Concierge Mode (answer A — beginners, non-technical users, creative-side-of-the-business users)

When the user picks A, switch into Concierge Mode and stay there until they say otherwise. In Concierge Mode:

1. **One step at a time.** Never paste a wall of commands. Never list "Phase 1 has these 5 commands." Show one command, wait for it to succeed, then show the next.
2. **Plain-English preamble before every command.** Before any command runs, the AI says in one sentence what it does — without jargon, ideally using an analogy from the user's world if you know what they do for work. Example: *"This next one checks whether your computer already has Docker installed — like opening a drawer to see if the scissors are there. It doesn't change anything."*
3. **Reassurance constantly.** Phrases like *"You can't break anything with this command,"* *"This is the same thing thousands of people run every day,"* *"If something goes wrong, I'll know and we'll fix it together."*
4. **Celebrate every success.** When a command works, the AI's next line includes a small win — *"Got it. ✨"* or *"That's one down."* or *"Beautiful — your computer just told us X is in place."* No fanfare, just warmth. Don't move on coldly.
5. **Translate every line of output.** When a terminal prints something, the AI explains what the user is looking at — *"What you're seeing here is just Docker confirming it's running. The number 4.28 is the version. Anything that long and version-shaped means we're good."*
6. **No jargon walls.** If the AI must use a word like "MCP server" or "SSH key" or "container," it follows with a one-sentence plain-English aside. **First use of every technical term gets a friendly aside.** Second use, no need.
7. **Adapt to user context.** If the user mentions what they do for a living (painter, baker, designer, teacher), draw analogies from that world. *"Installing Docker is like getting a new mixing palette — it gives us a clean surface to work on."*
8. **Single visible action per message.** Never give the user two things to do simultaneously. Even if a command takes 30 seconds to run, wait. Patience is the feature.
9. **Offer the way back.** Every few steps, remind the user: *"If anything feels off, just say 'pause' and I'll wait."* or *"Tell me 'explain that again' and I'll try a different angle."*
10. **At every phase boundary, celebrate.** Don't skip past it. *"Look at that — your laptop now has Docker. That's the workshop where everything else will live. Want to take a sip of coffee before we keep going?"*

### Express Mode (answer B — experienced users)

When the user picks B, run the skill compactly:

- One message per phase, all commands at once
- Skip plain-English preambles
- Verify in bulk at the end of each phase
- No celebrations between phases
- The user is presumed to know what `brew`, `docker info`, and `gh auth login` mean

You can still drop in a quick fix recommendation if a command fails. Express Mode is about pace, not silence.

### The hybrid case

Some users will say "I know what Docker is but I've never used `gh`." Treat the parts they know as Express, the parts they don't as Concierge. Ask if you're unsure.

## When to invoke

- A user invokes `/exoskeleton-install` and the probe finds missing prerequisites (any `✗` row → install missing pieces)
- A user invokes `/exoskeleton-install` and the probe finds drift (any `~` row → reconcile path; jump to Phase 5b)
- A user explicitly invokes `/exoskeleton-bootstrap` on a fresh machine (run all phases)
- A user explicitly invokes `/exoskeleton-bootstrap --reconcile` to fix MCP drift only (skip directly to Phase 5b)
- A user moved to a new laptop and wants the same stack working there

## Invocation modes

- **Default** (`/exoskeleton-bootstrap`) — full pass: Phase 0 (probe) → 1 (package manager) → 2 (CLI tools) → 3 (Docker) → 4 (credentials) → 5 (MCP install). Skips Phase 5b unless drift detected.
- **Reconcile** (`/exoskeleton-bootstrap --reconcile`) — jump straight to Phase 5b. Diffs existing MCPs against canonical fingerprints, asks the user per drift, preserves Foreign servers. Use after `/exoskeleton-install` probe reports `~` rows.
- **Clean** (`/exoskeleton-bootstrap --clean`) — explicitly remove all canonical MCPs first, then run Phase 5 fresh. Destructive; only use when the user explicitly asks for a clean reinstall.

## When NOT to invoke

- The user already has Docker running, git configured, `gh` authed, MCP servers installed. Run `/verify-stack` instead and skip ahead.

## Hard prerequisites this skill assumes

The skill cannot bootstrap *before* the user has:

1. **Claude Code installed and authenticated.** If you can read this SKILL.md, you have it.
2. **An OS we support** — macOS (12+), Linux (Ubuntu/Debian/Fedora), or Windows-via-WSL2.
3. **Admin access on the machine.** Multiple installs require sudo or admin password.

If any of these is missing, stop and tell the user what's needed.

## The six phases

Walk the user through these in order. Announce each phase. Use TodoWrite to track progress. **Verify after every install before moving on.**

### Phase 0 — System probe

Run all of these in parallel and read the results:

```bash
uname -s                              # OS detection
sw_vers -productVersion 2>/dev/null   # macOS version
cat /etc/os-release 2>/dev/null       # Linux distro
which docker                           # Docker installed?
docker info 2>&1 | head -3            # Docker daemon running?
which git
git --version
which gh
gh auth status 2>&1                   # GitHub CLI authed?
which python3
python3 --version
which jq
which node
node --version
ssh -V 2>&1                           # SSH client
ls ~/.ssh/id_*.pub 2>/dev/null        # SSH keys exist?
git config --global user.email        # git identity set?
claude mcp list 2>&1 | head -20       # which MCPs are wired?
```

Build a status table:

```
✓ Claude Code         (you're here)
✓ Git                 v2.40.1
✗ Docker              not installed
✗ gh CLI              not installed
✓ Python              3.11.6
✗ jq                  not installed
✓ Node                v20.10.0
✗ SSH key             ~/.ssh/id_ed25519 not found
✗ GitHub auth         not signed in
✗ git identity        user.email not set
✗ MCP servers         0 of 5 installed
```

Tell the user what's missing. Estimate time-to-green (typically 15–25 min for a fresh Mac).

### Phase 1 — Package manager

The skill needs a package manager to install everything else.

**macOS — Homebrew:**

If `which brew` is empty, install. The official command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This prompts for sudo. The skill cannot type the password — print the command, ask the user to run it in a terminal, then verify with `brew --version`.

**Linux:**

Use the native package manager (`apt`, `dnf`, `pacman`). No install needed. Skip to Phase 2.

**WSL2:**

Same as Linux inside the WSL2 shell. If the user is running PowerShell instead of WSL2, stop and direct them to `wsl --install` first.

### Phase 2 — Core CLI tools

Install everything except Docker (which has its own phase because of the GUI installer dance).

**macOS:**

```bash
brew install git gh jq python@3.12
```

Run this. Verify each with `--version`.

**Linux (Debian/Ubuntu):**

```bash
sudo apt-get update
sudo apt-get install -y git gh jq python3 python3-pip curl
```

The sudo prompt requires the user; the skill prints the command and waits.

**Linux (Fedora/RHEL):**

```bash
sudo dnf install -y git gh jq python3 python3-pip curl
```

Verify each tool individually after install. Don't move on if any failed.

### Phase 3 — Docker Desktop

Docker is its own phase because the install path differs significantly per OS.

**macOS:**

Cannot be brew-installed cleanly (the cask works but the GUI install is the supported path). Print this for the user:

> 1. Open https://www.docker.com/products/docker-desktop/
> 2. Click "Download for Mac" (correct chip: Intel or Apple Silicon — `uname -m` to check)
> 3. Run the `.dmg`, drag Docker to Applications
> 4. Launch Docker Desktop. Accept the license. Sign in (free Docker Hub account is fine, optional)
> 5. Wait for the whale icon in the menu bar to stop animating
> 6. Reply "done" so I can verify

Once the user replies, verify:

```bash
docker info | head -5
docker compose version
```

If either fails, tell the user exactly what to fix.

**Linux:**

Docker Engine (not Desktop) is the right install. Use the official convenience script:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

The `usermod` change requires the user to log out and back in (or `newgrp docker`). Tell them. Verify with `docker info` after they re-shell.

**WSL2:**

Docker Desktop on Windows with the WSL2 backend enabled — install on the Windows side, then verify inside WSL2 with `docker info`.

### Phase 4 — Credentials + accounts

**4a. git identity**

```bash
git config --global user.email
git config --global user.name
```

If either is empty, ask the user for their name + email and set them:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**4b. SSH key**

```bash
ls ~/.ssh/id_ed25519.pub 2>/dev/null
```

If missing, generate one. Ed25519 is the modern default:

```bash
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519 -N ""
```

(Empty passphrase makes the rest of the bootstrap frictionless. The user can rotate to a passphrased key later.)

**4c. GitHub auth**

```bash
gh auth status
```

If not authed, run:

```bash
gh auth login -p ssh -h github.com -w
```

This opens the browser. The skill cannot complete this — tell the user "watch your browser, paste the device code, click Authorize." Verify with `gh auth status` after.

Then upload the SSH key (gh handles it):

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-$(date +%Y-%m)"
```

Verify the key actually works:

```bash
ssh -T git@github.com 2>&1 | grep "successfully authenticated"
```

**4d. Anthropic API key**

If the user is running this skill, Claude Code is already authenticated. Verify by reading whatever auth indicator Claude Code exposes. Don't ask for keys directly — that's Claude Code's job.

If `claude` returns auth errors, point the user at `claude login` or `claude setup-token` per the Claude Code docs and have them retry.

### Phase 5 — The canonical MCP stack

**Important — the stack is opinionated, not configurable.** Every exoskeleton install gets the same six MCP servers. They were battle-tested together; switching one out breaks the others' assumptions. Tell the user which ones are coming and why, then install all six.

The canonical six:

| # | Server | Purpose | Why it earned its slot |
|---|---|---|---|
| 1 | **Serena** | Symbol-level code intel via LSP | Cuts read-token spend ~10× on real codebases. The AI jumps straight to a function body instead of grepping. |
| 2 | **jCodeMunch** | Repo-scale code intel — blast radius, dead code, dep graphs | The "what will break if I rename this?" tool. Forbids `Read`/grep on indexed code, in favor of structured retrieval. |
| 3 | **jDocMunch** | Section-level doc retrieval | Don't read a 1200-line markdown doc whole. Fetch the one section the AI needs. |
| 4 | **MemPalace** | Knowledge graph + memory drawers | The cross-session memory layer. Decisions, KnownBugs, Rules, per-branch Task state. SessionStart hook pre-loads relevant entries. |
| 5 | **Live DB MCP** | Direct database queries — stack-specific | Match this to `<PRIMARY_DB>`: **MariaDB by default**, postgres / sqlite as alternatives. AI queries the live schema instead of guessing. |
| 6 | **Playwright** | Browser automation | The AI clicks through your live preview like a user. Needed for E2E smoke tests later. |

#### Install commands

**1. Serena** — public + stable:

```bash
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant
```

**2. jCodeMunch**, **3. jDocMunch**, **4. MemPalace** — fetch the current install command from each project's README. These are the operator's-stack tools that evolve fast. The skill's job: ask the user where their copies live (if pulled locally) or grab the command from the maintainer's README. **Do not paste a hardcoded install line here that may be stale by the time someone runs this skill.** The command shape is always:

```bash
claude mcp add <name> -- <command-from-README>
```

If the user doesn't have access to these three yet, install Serena + DB MCP + Playwright and tell them: *"The remaining three (jCodeMunch, jDocMunch, MemPalace) are the high-leverage half — install them as soon as you have access. The stack works with Serena + DB + Playwright but loses the cross-cutting wiring map and the cross-session memory."*

**5. Live DB MCP** — the canonical default is **MariaDB** (matches the reference stack). Match `<PRIMARY_DB>`:

- **MariaDB** (default) → `claude mcp add mariadb -- npx -y mariadb-mcp-server` (then configure `MARIADB_HOST`, port, user, password in env via `.env` — never commit creds)
- **MySQL** → same `mariadb-mcp-server`, point at the MySQL host
- **PostgreSQL** (alternative) → `claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres "postgresql://localhost:5432/<PROJECT_SLUG>"`
- **SQLite** (alternative for tiny / single-user projects) → `claude mcp add sqlite -- npx -y @modelcontextprotocol/server-sqlite "/path/to/db.sqlite"`
- **Other** → ask the user for the connection string; install nothing speculatively.

**6. Playwright**:

```bash
claude mcp add playwright -- npx -y @executeautomation/playwright-mcp-server
```

#### Verify after each install

```bash
claude mcp list
```

The new server must appear. If it doesn't, **stop and debug** — never silently move on with a missing piece of the stack.

#### Why the stack is opinionated

The exoskeleton's discipline (Pre-Change Protocol, the four guards, parity check, cross-session memory) assumes specific tool capabilities:

- The Pre-Change Protocol assumes a queryable KG (MemPalace).
- The parity check assumes structured code retrieval (jCodeMunch).
- Tool Selection Protocol Question 1 forbids `Read`/grep on indexed code — there has to *be* an index (Serena + jCodeMunch).
- Doc question routing assumes section-level retrieval (jDocMunch).

Mix in a different tool and the protocol either fails closed or starts lying. Don't substitute.

### Phase 5b — Reconcile existing MCPs (adjust / update / remove)

When the user has an existing setup (not a fresh laptop), some MCPs may already be installed — possibly with **stale or wrong commands**. The probe alone only checks "does an MCP with this name exist?" — it doesn't catch "exists but misconfigured."

This phase reconciles. Use it when the user is **upgrading** to the canonical stack, not bootstrapping from scratch.

#### Step 1 — Inventory what's currently installed

```bash
claude mcp list 2>&1
```

For each row, the AI captures: (a) the server name, (b) the command it's registered with, (c) whether the name appears in our canonical six.

#### Step 2 — Diff against canonical

Compare against the canonical six. Three buckets:

- **Match** — server installed AND command matches the canonical → leave alone
- **Drift** — server installed BUT command differs (e.g. old Serena install path, stale version pin) → remove + reinstall
- **Foreign** — server installed but not part of the canonical six → leave alone unless the user says otherwise

#### Step 3 — Resolve drift

For each `Drift` entry, **ask the user first** in concierge mode. Example:

> Your `serena` MCP is installed but with a slightly different command than the canonical one:
> - Current: `uvx serena` (older path)
> - Canonical: `uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant`
> Do you want to update it? (y/n)

On `y`:

```bash
claude mcp remove <name>
claude mcp add <name> -- <canonical command>
```

On `n`, the AI documents the divergence in a note for later and moves on. Don't silently overwrite — drift may be intentional.

#### Step 4 — Add missing servers (same as Phase 5)

For canonical servers that aren't installed at all, fall back to the Phase 5 add commands.

#### Step 5 — Verify each adjustment landed

```bash
claude mcp list 2>&1 | grep -E "serena|jcodemunch|jdocmunch|mempalace|mariadb|postgres|sqlite|playwright|MCP_DOCKER|claude-in-chrome"
```

Confirm all canonical six (or their alias-equivalents) appear with the expected commands.

#### When to skip Phase 5b

If Phase 0's system probe came back with `0 of 6 MCPs installed`, skip 5b — there's nothing to reconcile, the fresh-install Phase 5 covers it.

If the user invoked the bootstrap with `--clean` (passed via the orchestrator), explicitly remove all existing canonical-six servers first, then run Phase 5 fresh. Don't reconcile — overwrite.

### Phase 6 — Final verification

Re-run the system probe from Phase 0. Every row should be green.

```bash
if docker info >/dev/null 2>&1; then echo "✓ Docker"; else echo "✗ Docker"; fi
if gh auth status >/dev/null 2>&1; then echo "✓ GitHub"; else echo "✗ GitHub"; fi
if git config --global user.email | grep -q '@'; then echo "✓ git identity"; else echo "✗ git identity"; fi
if [ -f ~/.ssh/id_ed25519.pub ] || [ -f ~/.ssh/id_rsa.pub ]; then echo "✓ SSH key"; else echo "✗ SSH key"; fi

# Every server in the canonical stack:
for srv in serena jcodemunch jdocmunch mempalace; do
  if claude mcp list 2>/dev/null | grep -q "$srv"; then echo "✓ $srv"; else echo "✗ $srv"; fi
done
# Browser automation — direct playwright OR MCP_DOCKER / claude-in-chrome alias paths:
if claude mcp list 2>/dev/null | grep -qE "playwright|MCP_DOCKER|claude-in-chrome"; then echo "✓ browser automation"; else echo "✗ browser automation"; fi
# Plus the DB MCP matched to the project's primary DB:
if claude mcp list 2>/dev/null | grep -qE "mariadb|postgres|sqlite"; then echo "✓ DB MCP"; else echo "✗ DB MCP"; fi
```

If all green, tell the user:

> Bootstrap complete. Your laptop is now a working AI dev environment. Next: `/exoskeleton-install` will create the project-specific stack (docker-compose, CLAUDE.md, guards, agents) on top of this foundation.

If any row is red, list what's missing with the specific next action. Do NOT auto-retry installs that failed — debug with the user first.

## Hard rules for this skill

1. **Never silently retry a failed install.** If brew install or apt-get fails, stop and surface the error. The user fixes it (often a network / permissions issue) and re-runs.
2. **Never store credentials.** Anthropic keys live in Claude Code's config. GitHub tokens live in `gh`'s config. SSH keys live in `~/.ssh/`. This skill writes nothing to any of those locations directly.
3. **Verify after every install.** Don't trust the install script's exit code alone — run the actual binary with `--version` or a status command.
4. **Print the command, then ask.** For anything that requires user action (sudo, browser auth, GUI installer), print the exact command/instructions and ask the user to reply "done" before verifying.
5. **macOS and Linux only.** Windows users must be inside WSL2. If `uname -s` returns anything Windows-shaped, tell the user to install WSL2 first (`wsl --install`).
6. **Idempotent.** Re-running this skill on an already-bootstrapped machine should be a no-op — every phase detects what's already in place and skips it.

## Time estimate per phase (fresh Mac)

| Phase | Time | Mostly waiting on |
|---|---|---|
| 0 — System probe | 30s | — |
| 1 — Homebrew | 3–5 min | network + sudo |
| 2 — CLI tools | 2–3 min | brew install |
| 3 — Docker Desktop | 5–8 min | manual download + GUI |
| 4 — Credentials | 2–4 min | browser auth |
| 5 — MCP servers | 3–5 min | per-tool installers |
| 6 — Verify | 30s | — |
| **Total** | **~20 min** | mostly downloads |

Linux is faster (no GUI install for Docker). WSL2 is in between.

## What this skill does NOT do

- **Set up a VPS account.** That's part of `/exoskeleton-deploy`. Hetzner / Linode / DigitalOcean account creation is outside scope.
- **Configure an IDE.** VS Code / Cursor / Zed setup is the user's call.
- **Install language runtimes for the user's project stack.** Rails needs Ruby, Django needs Python (already installed), Next.js needs Node (already there). The local-environment skill (Phase 1 of the project setup) handles stack-specific runtimes.
- **Auto-generate API keys.** It tells the user where to get each one and verifies after.

## Output the user should see when this skill finishes

```
EXOSKELETON BOOTSTRAP — COMPLETE

✓ macOS 14.4 (Apple Silicon)
✓ Homebrew 4.2
✓ git 2.44 — identity: Chris M <chris@example.com>
✓ Docker Desktop 4.28 — running
✓ gh 2.45 — authed as @chrismerkel
✓ SSH key — uploaded to GitHub
✓ Python 3.12, jq, Node 20.10
✓ MCP servers — serena, jcodemunch, jdocmunch, mempalace, mariadb, playwright (6/6)

→ Next: /exoskeleton-install
   creates the project stack on top of this.
```
