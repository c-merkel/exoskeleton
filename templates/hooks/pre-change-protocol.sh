#!/usr/bin/env bash
# Sentinel 1 — Pre-Change Protocol Hook
#
# Fires on Edit | Write | MultiEdit tool calls.
# Warns (default) or blocks (when <PROJECT_SLUG>_PCP_MODE=block) when a load-bearing
# file is about to be edited without the AI first querying the knowledge graph
# for the current shape of the wire this session.
#
# WHY: the AI's mental model of "what this file does" drifts across sessions.
# This hook nudges the AI to re-read the wire before editing it.
#
# Override: <PROJECT_SLUG>_SKIP_PCP=1 disables entirely. <PROJECT_SLUG>_PCP_MODE=block flips warn→block.

set -euo pipefail

# Skip if explicitly disabled
if [ "${<PROJECT_SLUG>_SKIP_PCP:-0}" = "1" ]; then
  exit 0
fi

# Read the tool call from stdin (Claude Code passes a JSON payload)
INPUT=$(cat 2>/dev/null || echo "{}")

# Extract the file path being edited
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
if [ -z "$FILE_PATH" ]; then
  exit 0  # No file path = no decision to make
fi

# Define which patterns are "load-bearing" — customize for your project
PROTECTED_PATTERNS=(
  "*/sync/*"
  "*/auth/*"
  "*/payment/*"
  "*/migrations/*"
  "*/api/*"
  "*/schema*"
)

# Check if the file matches a protected pattern
IS_PROTECTED=0
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == $pattern ]]; then
    IS_PROTECTED=1
    break
  fi
done

if [ "$IS_PROTECTED" = "0" ]; then
  exit 0  # Not a protected file
fi

# Check session state: has the KG been queried for this file's domain?
SESSION_DIR="${TMPDIR:-/tmp}/<PROJECT_SLUG>-session-${CLAUDE_SESSION_ID:-default}"
KG_QUERIED_MARKER="$SESSION_DIR/kg-queried"

if [ -f "$KG_QUERIED_MARKER" ]; then
  exit 0  # KG was queried this session — proceed
fi

# Default: WARN
MODE="${<PROJECT_SLUG>_PCP_MODE:-warn}"

MSG="⚠️  Pre-Change Protocol: file '$FILE_PATH' matches a protected pattern, and no KG query has been made this session. Consider querying the knowledge graph before editing."

if [ "$MODE" = "block" ]; then
  echo "$MSG" >&2
  echo "BLOCKED: invoke kg_query first, or set <PROJECT_SLUG>_SKIP_PCP=1 to override." >&2
  exit 2  # Exit code 2 = block the tool call
fi

# WARN mode: print to stderr but allow the call
echo "$MSG" >&2
exit 0
