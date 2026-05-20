#!/usr/bin/env bash
# Autonomic layer 4 — Self-stop watchdog (drift reflex)
#
# Fires PostToolUse on Edit | Write | MultiEdit. Observes the per-session
# action sequence and intervenes when the AI's behavior is drifting:
#
#   D1. Edit on a file that was never Read this session.
#       → "Current state may differ from memory. Read before changing."
#
#   D2. ≥3 Edits on the same file with no smoke / build / test fired between.
#       → "Stop. Build / smoke / verify before the next edit."
#
# Reads state from the session-dir laid down by ambient-impact.sh:
#   reads.log  — dedup list of files Read this session
#   edits.tsv  — append-only: <ts>\t<tool>\t<file>
#
# Warn-only — never blocks. The intervention IS the context injection;
# the AI decides what to do.
#
# Override:
#   <PROJECT_SLUG>_SKIP_WATCHDOG=1               one-shot skip
#   touch ${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-watchdog   machine-wide skip

set +e
JSON_INPUT=$(cat 2>/dev/null || echo "{}")

source "$(dirname "$0")/lib-session.sh"

if [ "${<PROJECT_SLUG>_SKIP_WATCHDOG:-0}" = "1" ] || [ -f "${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-watchdog" ]; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception: pass" 2>/dev/null)
  TOOL_NAME=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_name',''))
except Exception: pass" 2>/dev/null)
fi

[ -z "$FILE_PATH" ] && exit 0
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) : ;;
  *) exit 0 ;;
esac

SID=$(extract_session_id "$JSON_INPUT")
DIR=$(session_dir "$SID")
READS_LOG="$DIR/reads.log"
EDITS_LOG="$DIR/edits.tsv"

# Chicken-and-egg: first edit of session — nothing to detect yet.
[ ! -f "$EDITS_LOG" ] && exit 0

# --- D1: Edit on file never Read this session -----------------------------
# Skip the warning if the file is brand new (Write creating it) — newly
# created files have no prior state to read.
EXISTED_BEFORE=1
[ -f "$FILE_PATH" ] || EXISTED_BEFORE=0

if [ "$EXISTED_BEFORE" = "1" ]; then
  if ! grep -qxF "$FILE_PATH" "$READS_LOG" 2>/dev/null; then
    EDIT_COUNT=$(grep -c -F "	$FILE_PATH" "$EDITS_LOG" 2>/dev/null | head -1)
    EDIT_COUNT=${EDIT_COUNT:-0}
    if [ "$EDIT_COUNT" -le 1 ]; then
      cat >&2 <<EOF

⚠️  Watchdog D1 — Edit without prior Read

  File: $FILE_PATH
  No Read of this file was recorded earlier in the session.

  Current on-disk state may differ from your assumption (other agents,
  git pull, manual edit). Reading first costs ~1s and prevents the
  "edited stale snapshot" failure mode.

  Override: <PROJECT_SLUG>_SKIP_WATCHDOG=1 (one-shot)

EOF
    fi
  fi
fi

# --- D2: ≥3 edits on same file in last 6 edit-class actions ---------------
RECENT=$(tail -n 6 "$EDITS_LOG" 2>/dev/null | awk -F'\t' -v fp="$FILE_PATH" '$3 == fp { print }' | wc -l | tr -d ' ')
RECENT=${RECENT:-0}

if [ "$RECENT" -ge 3 ]; then
  ENTITY_HINT=""
  REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  if [ -f "$REPO_ROOT/qa/lib/entity_shapes.py" ]; then
    ENTITY_HINT=$(python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/qa/lib')
try:
    from entity_shapes import resolve_entity_for_path
    key, data = resolve_entity_for_path('$FILE_PATH')
    if key: print(f'(entity: {data.get(\"display_name\", key)})')
except Exception: pass
" 2>/dev/null)
  fi

  cat >&2 <<EOF

⚠️  Watchdog D2 — Rapid-fire editing without verification

  File: $FILE_PATH $ENTITY_HINT
  $RECENT edits on this file in the last 6 Edit-class actions.

  CLAUDE.md "stop and re-plan on drift" applies — when a fix doesn't take,
  pushing more edits wastes tokens and breaks more code. Before the next
  edit, do one of:

    • Build / type-check the relevant module
    • Smoke the actual flow end-to-end
    • Verify the actual problem: re-read, re-query the KG, restate plan

  Override: <PROJECT_SLUG>_SKIP_WATCHDOG=1 (one-shot)

EOF
fi

exit 0
