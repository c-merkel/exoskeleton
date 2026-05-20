#!/usr/bin/env bash
# Sentinel 2 — Schema-Verify
#
# Fires before any live-DB tool call. Parses the SQL for destructive verbs.
# If the SQL targets a table that has NOT been inspected this session
# (via get_table_schema), refuses the call.
#
# WHY: the AI's mental model of a table's shape drifts. Forcing a fresh
# schema read before any destructive op catches stale-schema bugs early.
#
# This is the canonical example of the asymmetry — an AI can argue at any
# length why the call should be allowed. This script reads a state file
# and a regex. It cannot be persuaded.
#
# Override: <PROJECT_SLUG>_SKIP_SCHEMA_CHECK=1.

set -euo pipefail

if [ "${<PROJECT_SLUG>_SKIP_SCHEMA_CHECK:-0}" = "1" ]; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || echo "{}")
SQL=$(echo "$INPUT" | jq -r '.tool_input.sql // .tool_input.query // empty' 2>/dev/null || echo "")
if [ -z "$SQL" ]; then
  exit 0  # No SQL = nothing to gate
fi

# Allow SELECT and CREATE TABLE through (read or new table)
if echo "$SQL" | grep -qiE '^[[:space:]]*(SELECT|SHOW|DESCRIBE|EXPLAIN|CREATE[[:space:]]+TABLE)'; then
  exit 0
fi

# Check if this is a destructive verb
DESTRUCTIVE_VERBS='INSERT|UPDATE|DELETE|ALTER|DROP|TRUNCATE|RENAME'
if ! echo "$SQL" | grep -qiE "^[[:space:]]*($DESTRUCTIVE_VERBS)\\b"; then
  exit 0  # Not destructive
fi

# Extract the target table name (rough but works for most cases)
TARGET_TABLE=$(echo "$SQL" | grep -oiE "(INTO|FROM|TABLE|UPDATE)[[:space:]]+\`?([a-zA-Z_][a-zA-Z0-9_]*)\`?" | head -1 | awk '{print $NF}' | tr -d '`')

if [ -z "$TARGET_TABLE" ]; then
  # If we can't parse the table, fail closed
  echo "⚠️  Schema-Verify: could not parse target table from SQL. Refusing as a precaution." >&2
  exit 2
fi

# Check the session state file
SESSION_DIR="${TMPDIR:-/tmp}/<PROJECT_SLUG>-session-${CLAUDE_SESSION_ID:-default}"
TABLE_INSPECTED_MARKER="$SESSION_DIR/inspected-table-${TARGET_TABLE}"

if [ -f "$TABLE_INSPECTED_MARKER" ]; then
  exit 0  # Table was inspected — proceed
fi

# Refuse
echo "🛑 Schema-Verify: table '$TARGET_TABLE' has not been inspected this session." >&2
echo "    Invoke get_table_schema('$TARGET_TABLE') first." >&2
echo "    To override (rare and risky): set <PROJECT_SLUG>_SKIP_SCHEMA_CHECK=1." >&2
exit 2  # Block the call

