#!/usr/bin/env bash
# Shared session-state helpers used by the autonomic-layer hooks.
#
# Sourced by ambient-impact.sh, self-stop-watchdog.sh, learn-from-correction.sh,
# recall-topic-area.sh. Provides a single canonical session-dir resolver so
# every hook touches the same per-session state.
#
# Session-dir layout (under ${TMPDIR:-/tmp}/<PROJECT_SLUG>-session-<sid>/):
#   touched-files.log    — dedup list of every Read/Edit/Write target
#   reads.log            — dedup list of Read targets
#   edits.tsv            — append-only: <unix_ts>\t<tool>\t<file>
#   entity-surfaced.log  — dedup list of entity keys we've emitted ambient dossiers for
#   kg-queried           — marker file written when the KG MCP fires (sentinel-1 PCP)
#   inspected-table-*    — marker files written when get_table_schema fires (sentinel-2)
#
# Override:
#   <PROJECT_SLUG>_SESSION_DIR_OVERRIDE — if set, used verbatim as the session dir.

session_dir() {
  local sid="${1:-default}"
  if [ -n "${<PROJECT_SLUG>_SESSION_DIR_OVERRIDE:-}" ]; then
    local dir="${<PROJECT_SLUG>_SESSION_DIR_OVERRIDE}"
  else
    local base="${TMPDIR:-/tmp}/<PROJECT_SLUG>-session"
    local dir="${base}/${sid}"
  fi
  mkdir -p "$dir" 2>/dev/null || true
  echo "$dir"
}

extract_session_id() {
  local json="$1"
  local sid=""
  if command -v jq >/dev/null 2>&1; then
    sid=$(echo "$json" | jq -r '.session_id // empty' 2>/dev/null)
  else
    sid=$(echo "$json" | python3 -c "import json,sys
try:
    d=json.load(sys.stdin); print(d.get('session_id',''))
except Exception:
    pass" 2>/dev/null)
  fi
  # Fall back to env var if JSON didn't carry it (older Claude Code versions
  # exposed CLAUDE_SESSION_ID instead of the .session_id JSON field).
  if [ -z "$sid" ]; then
    sid="${CLAUDE_SESSION_ID:-default}"
  fi
  echo "$sid"
}
