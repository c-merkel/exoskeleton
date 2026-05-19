---
description: Convert a long debugging session into durable memory. Creates a KnownBug entry in the knowledge graph and prompts the user to write the corresponding Rule that prevents the class of bug from recurring.
allowed-tools: Bash, Read, Write, Edit
---

# /learn

You just spent 30+ minutes finding a bug. Don't lose what you learned. This command writes it into the knowledge graph.

## When to invoke

- A bug took more than 30 minutes to find
- A bug recurred despite a prior fix attempt
- A pattern emerged that should never happen again
- A subtle behavior surprised you and you want future-you to know

## What this command does

### Step 1 — Capture what just happened

Ask the user three questions (one at a time, plain English):

1. **What did you discover?** — the actual root cause in one sentence
2. **What was the symptom?** — what you saw that made you look
3. **What's the class of bug?** — what category does this belong to (e.g. "wire-format mismatch," "race condition on cold start," "permission check missing on admin route")

Wait for each answer before asking the next.

### Step 2 — Write the KnownBug entry

Append a `KnownBug:<short-name>` entity to the knowledge graph (via the KG MCP). Fields:

- `name`: short kebab-case label
- `class`: the category the user named
- `symptom`: what they saw
- `root_cause`: the actual cause
- `files_touched`: list of files in the fix commit
- `date_found`: today's date
- `fix_commit`: the commit SHA that resolved it

### Step 3 — Propose the Rule

Bugs are one-offs; rules prevent the class. Draft a `ChrisRule:<name>` (or `Rule:<name>` if not personal-style) that, if followed, would have prevented this bug.

Format: one-line imperative, followed by **Why:** and **How to apply:**.

Example:
```
ChrisRule:NeverTrustClientTotalAmount

Server must recompute money fields from canonical sources — never trust a client-supplied `total_amount`.

Why: A pricing race in 2026-03 let a manipulated client submit a $0 booking for a $400 service. Backend trusted the client value.

How to apply: Every controller action that accepts a `*_amount` field must recompute the value server-side from line items before persisting.
```

### Step 4 — Show the user the draft Rule and ask for sign-off

Present the proposed Rule. Wait for one of:
- "yes" → write the rule to the KG
- "edit X" → user adjusts the wording, you re-show
- "skip" → just save the KnownBug without a rule

### Step 5 — Confirm + close

After writing, tell the user:
- Where the KnownBug + Rule landed in the KG
- That the rule will surface in future sessions when the auto-recall hook fires on related patterns
- The bug is now "vaccinated" — won't happen again silently

## Output the user should see

```
KnownBug:wire-format-mismatch-customer-channel saved
ChrisRule:ParityFailIsShipBlocker proposed

The rule will surface automatically in future sessions where the
parity check runs. The bug is now vaccinated.
```
