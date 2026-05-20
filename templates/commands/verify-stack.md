---
description: Health check — verifies the exoskeleton stack is installed correctly. Runs 8 checks and reports green / yellow / red with the specific next action per failure.
allowed-tools: Bash, Read, Glob
---

# /verify-stack

Run the 8-check health pass on the exoskeleton stack. Report PASS/FAIL/SKIP per check with one specific next action per failure.

## The 8 checks

### 1. Docker stack starts cleanly

```bash
docker compose ps --format json 2>/dev/null | head -1
docker compose up -d --quiet-pull 2>&1 | tail -5
```

Expected: services start without error. Fix: read the error, usually a port conflict or missing env var.

### 2. Live preview reachable

```bash
curl -sf -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

Expected: HTTP 200. Fix: `docker compose logs web` to find the error.

### 3. CLAUDE.md exists and is non-trivial

```bash
[ -f CLAUDE.md ] && [ $(wc -l < CLAUDE.md) -ge 50 ] && echo "✓ CLAUDE.md OK" || echo "✗ CLAUDE.md missing or stub"
```

Fix: re-run `/exoskeleton-manual`.

### 4. Four Sentinel scripts present + pass `bash -n`

```bash
for f in .claude/hooks/pre-change-protocol.sh .claude/hooks/schema-verify.sh .claude/hooks/kg-staleness-check.sh .githooks/pre-commit; do
  [ -f "$f" ] && bash -n "$f" && echo "✓ $f" || echo "✗ $f"
done
```

Fix: re-run `/exoskeleton-guards`.

### 5. Pre-commit hook is wired

```bash
git config core.hooksPath
```

Expected: `.githooks`. Fix: `git config core.hooksPath .githooks`.

### 6. Agent definitions parse as valid markdown with frontmatter

```bash
for f in .claude/agents/architect.md .claude/agents/executor.md .claude/agents/researcher.md; do
  head -5 "$f" | grep -q '^name:' && echo "✓ $f" || echo "✗ $f"
done
```

Fix: re-run `/exoskeleton-manual`.

### 7. Slash commands registered

```bash
ls .claude/commands/*.md 2>/dev/null | head -10
```

Expected: at least `/plan`, `/verify-stack`, `/learn`. Fix: re-run `/exoskeleton-manual`.

### 8. MCP servers responding

```bash
claude mcp list 2>&1 | grep -E "serena|jcodemunch|jdocmunch|mempalace|mariadb|postgres|sqlite|playwright" | wc -l
```

Expected: ≥ 6. Fix: invoke `/exoskeleton-bootstrap` to install missing servers.

## Report format

After running all 8 checks, output a status summary:

```
═══ EXOSKELETON STACK — HEALTH CHECK ═══

  ✓ Docker stack running
  ✓ Live preview reachable
  ✓ CLAUDE.md exists
  ✓ 4 Sentinel scripts syntax-clean
  ✓ Pre-commit hook wired
  ✓ Agent definitions present
  ✗ Slash commands missing — re-run /exoskeleton-manual
  ✓ 7 MCP servers responding

7 / 8 checks GREEN · 1 RED
```

Top-line summary: total green / total · one-line next action if any red.

