#!/usr/bin/env bash
# Auxiliary nudge — KG Staleness Check
#
# Fires when the AI queries the knowledge graph. If there are >= 5 uncommitted
# mineable file edits, warn that the KG reflects the LAST refresh — not the
# in-progress work. Helps avoid the "I queried the KG and built on stale data"
# class of bug.
#
# This is the lightest of the four Sentinels. Always warn-only.
#
# Override: touch /tmp/<PROJECT_SLUG>-skip-kg-nudge to silence for the session.

set -euo pipefail

SKIP_MARKER="${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-kg-nudge"
if [ -f "$SKIP_MARKER" ]; then
  exit 0
fi

# Mark the KG as queried this session (used by pre-change-protocol.sh)
SESSION_DIR="${TMPDIR:-/tmp}/<PROJECT_SLUG>-session-${CLAUDE_SESSION_ID:-default}"
mkdir -p "$SESSION_DIR"
touch "$SESSION_DIR/kg-queried"

# Count uncommitted mineable file edits — customize the find pattern for your stack
UNCOMMITTED_COUNT=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(py|js|ts|tsx|swift|php|rb|go|rs)$' | wc -l | tr -d ' ')

if [ "$UNCOMMITTED_COUNT" -ge 5 ]; then
  echo "⚠️  KG Staleness: $UNCOMMITTED_COUNT uncommitted mineable edits. The knowledge graph reflects the last refresh, not the in-progress work." >&2
  echo "    To silence for this session: touch $SKIP_MARKER" >&2
fi

exit 0

