---
name: exoskeleton-promote
description: Bidirectional sync between a consumer project (e.g. FMM) and the exoskeleton bundle. Diffs the consumer's installed hooks / templates against the canonical published versions, classifies each delta as project-specific (stays put), lift-worthy (promote upstream), or stale (consumer behind public). The upstream channel for FMM-style improvements to flow into the public exoskeleton without copy/paste or memory loss.
---

# Exoskeleton — Promote (the upstream channel)

The exoskeleton publishes generic templates. Consumers (FMM, sibling projects) install them and may evolve them locally — tighten a detector, add a new entity, refine a regex. Without a deliberate channel, those evolutions stay locked in the consumer and the public bundle stagnates.

This skill **is** that channel.

## When to invoke

- Periodically from a consumer project (default cadence: every 2-4 weeks of active autonomic-layer use). Promotes the lift-worthy local improvements upstream.
- After a long FMM session that materially evolved one of the hooks. The new behavior is locally validated; this skill tests whether the change is generic enough to publish.
- Before reinstalling the exoskeleton onto an existing consumer (the consumer's customizations get inventoried first so the reinstall can preserve them).

## What this skill produces

Two artifacts per invocation:

1. **`promote-report.md`** at the consumer project root. Human-readable inventory:
   - `## Stale` — files where the consumer is BEHIND the public (public has improvements the consumer doesn't). Reinstall candidate.
   - `## Lift-worthy` — files where the CONSUMER has improvements beyond the public. Promotion candidates.
   - `## Project-specific` — files where the consumer's version is fundamentally different (FMM-only entities, project-only env vars). Stays put forever.
   - `## Unchanged` — files identical after placeholder substitution.

2. **`promote-patches/`** at the consumer project root (gitignored). One `.patch` per lift-worthy file. Apply with `git -C <exoskeleton-clone> apply` to draft the upstream PR.

## The walkthrough

### Step 1 — Locate both repos

Ask the operator (or detect):

- **Consumer repo**: assumed to be the current working directory's git root.
- **Exoskeleton clone**: by default `~/Documents/Claude/Projects/exoskeleton`. Confirm or take an override path.

If the exoskeleton clone is at `.claude/skills/exoskeleton/` (i.e., it was installed-into-tree rather than peer), that's fine — diff that path. Just don't propose pushing from a tree that lives inside the consumer.

### Step 2 — Resolve the consumer's project slug

Read `.claude/settings.json` from the consumer:

```bash
SLUG=$(jq -r '.env.PROJECT_SLUG // empty' .claude/settings.json)
```

If empty, ask the operator. The slug substitutes into the public templates so the diff doesn't trip on every env var name.

### Step 3 — For each shippable file in the exoskeleton bundle, diff

Files that ship as templates have a one-to-one consumer destination:

| Template path | Consumer destination |
|---|---|
| `templates/hooks/*.sh` | `.claude/hooks/<filename>` |
| `templates/githooks/{pre,post}-commit` | `.githooks/{pre,post}-commit` |
| `templates/qa/lib/entity_shapes.py` | `qa/lib/entity_shapes.py` |
| `templates/qa/check-shape-coverage.py` | `qa/check-shape-coverage.py` |
| `templates/qa/mine-entity-shapes.py.template` | `qa/mine-entity-shapes.py` (no .template suffix) |
| `templates/qa/entity-shapes.config.yaml.template` | `qa/entity-shapes.config.yaml.template` (consumer copies + customizes manually) |
| `templates/settings.json.template` | `.claude/settings.json` (consumer extends with their own permissions) |
| `templates/CLAUDE.md.template` | `CLAUDE.md` (consumer fills placeholders) |

For each pair:

```bash
EXO_FILE=$EXO/templates/hooks/ambient-impact.sh
CONS_FILE=.claude/hooks/ambient-impact.sh

# Substitute the consumer's slug into the template version
sed "s/<PROJECT_SLUG>/$SLUG/g" "$EXO_FILE" > /tmp/expected.sh
diff -u /tmp/expected.sh "$CONS_FILE" > /tmp/delta.diff

# Categorize:
#   no diff                                            → Unchanged
#   diff is purely additive on consumer side           → Lift-worthy
#   diff is purely additive on exoskeleton side        → Stale (consumer behind)
#   diff has both adds + deletes / structural divergence → Project-specific
```

Heuristic for additive-on-consumer-side: every changed hunk in the diff has more `+` lines than `-` lines AND no `-` line removes a function call / control structure.

If automated classification is ambiguous, present the diff to the operator and let them decide which bucket.

### Step 4 — For consumer-specific files (no template), inventory them

Some files in `.claude/hooks/` exist in the consumer but have NO template counterpart (e.g., FMM's `enforce-schema-verify.sh` may have FMM-specific signal beyond the public template). List these under `## Project-specific` with a note that they're consumer-only.

For consumer extensions to shared files (the obvious case: `.githooks/pre-commit` where the consumer has added gates the public doesn't ship), the diff will land in `## Project-specific` because the divergence is structural, not additive.

### Step 5 — Write `promote-report.md`

Compose the report with the four sections. For each lift-worthy file, include:
- The diff hunk in a fenced code block
- A suggested commit message
- Any placeholder generalization needed (e.g., a hardcoded FMM entity name → config field)

For each stale file, include:
- The public-side improvements the consumer is missing
- A risk assessment (does updating break the consumer's customizations?)

### Step 6 — Write `promote-patches/<filename>.patch` for each lift-worthy entry

```bash
mkdir -p promote-patches
# For each lift-worthy file, generate a patch that applies to the exoskeleton tree
diff -u "$EXO_FILE" "$CONS_FILE" > promote-patches/<filename>.patch
# But strip the consumer's slug substitution first
sed -i "s/$SLUG/<PROJECT_SLUG>/g" promote-patches/<filename>.patch
```

Add `promote-patches/` to the consumer's `.gitignore` if not already there — these are working files, not committed artifacts.

### Step 7 — Walk the operator through the report

Show the operator the four-bucket inventory. Ask:

- **For each lift-worthy entry**: "Is this generic enough to publish, or does it depend on something FMM-specific?" If yes-publish: apply the patch in the exoskeleton clone, propose a commit message, ask for go-ahead to push.
- **For each stale entry**: "Want to pull the public improvement into the consumer? Risk: <assessment>." If yes: copy the public version with placeholder substituted into the consumer's hook path.
- **For each project-specific entry**: documented and skipped. No action.
- **For each unchanged entry**: documented and skipped. No action.

### Step 8 — On the exoskeleton side, draft the commit + PR

After all approved lift-worthy patches are applied to the exoskeleton tree, generate a single transactional commit:

```
feat(<area>): lift improvements from <consumer-slug>

<bullet list of lifted changes>

Source: <consumer-slug> commit <sha>
Co-Authored-By: <operator-name> via Claude Code
```

Push when the operator says go. Do NOT push without explicit approval — this is a public repo, churn matters.

## Hard rules

1. **No silent overwrites.** Every lift-worthy or stale change is shown to the operator before any file is touched.
2. **Slug-substitute before diffing.** A diff that's purely `FMM_SKIP_PCP` vs `<PROJECT_SLUG>_SKIP_PCP` is NOT a real delta. Always substitute first.
3. **Generic test before lift.** Before promoting, ask: "Does this improvement assume something specific to the consumer (file paths, env names, business logic)?" If yes → it's project-specific, not lift-worthy.
4. **Apply lifts to the exoskeleton in a worktree or feature branch.** Never directly to `main`. The operator pushes when satisfied.
5. **Tie lifts to consumer commits.** Each lifted change traces back via commit message to a commit in the consumer. Provenance matters.
6. **Promote-patches are working files.** Add to `.gitignore`; delete after the PR lands.

## When this skill is the wrong tool

- **First-time install on a consumer** → use `/exoskeleton-install`, not promote.
- **Pulling exoskeleton updates into a consumer** → handled by Step 7's stale section, but if it's a major version bump, use a fresh `/exoskeleton-guards` re-install with `--preserve-customizations` instead.
- **Capturing a single one-off improvement** → faster to manually copy the diff. Promote is for periodic batch lifts.

## Output the operator should see when this skill completes

> Promote report written to `promote-report.md`.
>
> Inventory:
>   • Unchanged: <N> files (nothing to do)
>   • Stale: <N> files (consumer behind public; pull?)
>   • Lift-worthy: <N> files (consumer ahead of public; promote?)
>   • Project-specific: <N> files (stays put)
>
> Lift-worthy patches drafted in `promote-patches/`. Review the report, then approve which to push.
