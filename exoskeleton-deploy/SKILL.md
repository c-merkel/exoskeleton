---
name: exoskeleton-deploy
description: VPS deployment wizard for the Exoskeleton stack. Runs ONLY after local environment is green. Asks for SSH credentials, explains the production topology, generates deploy.sh + rollback.sh + a backup hook. Walks through Caddy auto-TLS setup, environment variables, and a first deploy with safe rollback. Never runs automatically — always explicit.
---

# Exoskeleton — VPS Deployment

This skill walks the production-server side of the Exoskeleton stack: deploying the same Docker topology that's running on your laptop to a VPS, with Caddy auto-TLS and a safe rollback path.

**This skill never runs automatically.** The orchestrator does not invoke it. The user has to type `/exoskeleton-deploy` explicitly, after their local stack is green and they've decided they want to deploy.

## When to invoke

- The user has run `/exoskeleton-install` and the local stack is up
- `/verify-stack` is green
- The user wants to deploy to a production server (any VPS — IONOS, Hetzner, Linode, DigitalOcean, AWS Lightsail, your home server)

## Hard prerequisites (verify before doing anything)

The skill must verify each of these before proceeding:

1. **Local stack is up.** `docker compose ps` shows all services running.
2. **`/verify-stack` returned green.** If not, abort.
3. **`docker-compose.yml` is committed to git.** Not just on disk — committed.
4. **The user has explicit ownership of the target server** (SSH access with sudo) and confirms they want to deploy.
5. **A domain name is pointing at the server's public IP.** This is required for Caddy auto-TLS to issue a certificate.

If any of these fails, stop and tell the user exactly what's missing.

## Walkthrough

### Step 1 — Explain the topology before touching anything

Tell the user, in plain English:

> Production runs the same `docker-compose.yml` as your laptop. Same services. Same images. Same database engine. The only differences:
>
> 1. The production server has a public IP.
> 2. Caddy auto-issues TLS for your domain.
> 3. Environment variables live in `/etc/<PROJECT_SLUG>/.env` (not in the repo).
> 4. The deploy script takes a database backup before every deploy.
> 5. If the post-deploy health check fails, the previous version is restored from that backup automatically.
>
> The deploy is one command: `bin/vps/deploy.sh`. The rollback is one command: `bin/vps/rollback.sh`. Both are about 30 lines of bash. You'll read them before you trust them.

Wait for the user to confirm they understand.

### Step 2 — Ask for VPS specifics

In ONE message (use AskUserQuestion if available), ask:

1. **VPS provider + region** (informational)
2. **Server hostname or IP** (e.g., `203.0.113.42` or `prod.example.com`)
3. **SSH user** (e.g., `chris`, `deploy`, `ubuntu`)
4. **SSH key path** (e.g., `~/.ssh/id_ed25519_vps`)
5. **Production domain** (e.g., `app.example.com`)
6. **Database admin password** (the user provides this; the skill does not write it to disk in clear)
7. **An optional SSH alias name** (so the user can type `ssh prod` instead of the full hostname)

**Never log credentials to stdout or write them to a committed file.**

### Step 3 — Add SSH aliases to `~/.ssh/config`

Append (don't overwrite) entries to the user's `~/.ssh/config`:

```
Host <ALIAS>
  HostName <HOSTNAME>
  User <SSH_USER>
  IdentityFile <SSH_KEY_PATH>
  IdentitiesOnly yes
```

Tell the user. Confirm they can `ssh <ALIAS>` and reach the server before continuing.

### Step 4 — Generate `bin/vps/deploy.sh`, `bin/vps/rollback.sh`, `bin/vps/health-check.sh`

Use templates at `templates/vps/`. The deploy script:

1. SSH to the production server
2. Verify Docker is running
3. Take a database backup → `/var/backups/<PROJECT_SLUG>/<timestamp>.sql.gz`
4. `git pull` the production checkout
5. `docker compose pull && docker compose up -d`
6. Wait for the health check to pass (configurable timeout)
7. If health check fails → restore the backup, rollback the git checkout, exit 1
8. If health check passes → emit `SAVED: <git_sha>` and exit 0

The rollback script:
1. Find the most recent backup
2. SSH to production
3. Restore the backup
4. `git reset --hard HEAD~1`
5. Restart the stack

The health check is a small bash script that hits a known endpoint and verifies it returns 200.

### Step 5 — Write `etc/Caddyfile.template` and `etc/<PROJECT_SLUG>.env.example`

A minimal Caddyfile (Caddy is the recommended default — any reverse proxy with auto-TLS works, including nginx with certbot, Traefik, or any cloud-managed terminator):

```caddy
<DOMAIN> {
    reverse_proxy web:8080
    encode gzip
    log {
        output file /var/log/caddy/access.log
    }
}
```

Caddy auto-issues a Let's Encrypt cert when first hit. No additional cert config needed.

The `.env.example` template lists every environment variable the production stack expects, with comments. Tell the user to copy it to `/etc/<PROJECT_SLUG>/.env` on the server and fill in the secrets manually (this skill does not write secrets to disk).

### Step 6 — Pre-flight check

Before running the first deploy, run `bin/vps/health-check.sh` against the LOCAL stack. If it passes, the deploy script logic is sound. If it fails, fix it before running against prod.

### Step 7 — Run the first deploy (only with explicit user OK)

Tell the user:

> Ready to run the first deploy. The deploy will:
> 1. Take a database backup on the server
> 2. Pull the latest commit
> 3. Restart the stack
> 4. Run the health check
> 5. Rollback if anything fails
>
> This will affect your production server. Confirm with: "go"

Only run on explicit "go".

After the first deploy, surface the public URL and the production health check result.

### Step 8 — Document the operations

Write a short `qa/RUNBOOK_vps_ops.md` (or similar) into the project:

- How to ssh to prod
- How to view logs (`docker compose logs -f`)
- How to deploy (`bin/vps/deploy.sh`)
- How to rollback (`bin/vps/rollback.sh`)
- Where backups live
- Where the env file lives

## Hard rules

1. **Never run automatically.** This skill only runs on explicit `/exoskeleton-deploy` invocation.
2. **Never write secrets to a committed file.** `.env` files with secrets live on the server, in a path that's NOT inside the git checkout.
3. **No force-push.** No `git reset --hard` to anything other than `HEAD~1` (the rollback case).
4. **Pre-deploy backup is mandatory.** Every deploy takes a backup first. If the backup fails, the deploy fails.
5. **Always have a rollback path before going forward.** If you can't `bin/vps/rollback.sh`, you can't `bin/vps/deploy.sh`.
6. **The first deploy is supervised.** Subsequent deploys can be one-command after you trust the system.

## Output the user should see

When this skill completes:

> Production stack deployed to `https://<DOMAIN>`.
> Backup at `/var/backups/<PROJECT_SLUG>/<timestamp>.sql.gz`.
> Deploy: `bin/vps/deploy.sh`
> Rollback: `bin/vps/rollback.sh`
> Logs: `ssh <ALIAS> docker compose logs -f`
> Runbook: `qa/RUNBOOK_vps_ops.md`
>
> The stack is now mirrored between your laptop and the production server. The hooks, the agents, the Sentinels, the operating manual — they all work the same in both places.
>
> Push to production when you're ready: `git push && bin/vps/deploy.sh`

