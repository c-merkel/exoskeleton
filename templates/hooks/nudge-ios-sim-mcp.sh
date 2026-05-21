#!/usr/bin/env bash
# templates/hooks/nudge-ios-sim-mcp.sh
#
# PreToolUse hook for `mcp__ios-simulator__*` calls. Emits a single-line
# nudge suggesting the `xcodebuildmcp` CLI equivalent — the CLI is far
# more token-efficient for batch / scripted work and supports tap-by-
# accessibility-id / -label (no coordinate guessing). One-off interactive
# use of the MCP is still fine.
#
# Skippable via the standard project skip flag:
#   <PROJECT_SLUG>_SKIP_NUDGE_IOS_SIM_MCP=1
# Exits 0 always — never blocks.

set -u
[ "${<PROJECT_SLUG>_SKIP_NUDGE_IOS_SIM_MCP:-0}" = "1" ] && exit 0

input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool" in
    mcp__ios-simulator__ui_tap)
        cat <<'EOF' >&2
[nudge] mcp__ios-simulator__ui_tap is fine for a one-off, but for any
        batch / scripted iOS QA prefer the xcodebuildmcp CLI:
          xcodebuildmcp ui-automation tap --id "<accessibility-id>"
        Tap-by-id is bulletproof vs x/y coordinates (no misses when the
        tab bar shifts / device class changes). Pair with /exoskeleton-mobile-ax
        to ensure your app has .ax(...) ids on every tappable.
EOF
        ;;
    mcp__ios-simulator__ui_describe_all)
        cat <<'EOF' >&2
[nudge] For scripted view-hierarchy inspection prefer the CLI:
          xcodebuildmcp simulator snapshot-ui --output jsonl | jq ...
        Same data, pipe-friendly, no agent context burn per call.
EOF
        ;;
    mcp__ios-simulator__screenshot)
        cat <<'EOF' >&2
[nudge] For batched screenshot capture prefer the CLI (no agent context
        burn per shot):
          xcodebuildmcp simulator screenshot --output-path /tmp/foo.png
        Reserve the MCP for shots you intend to read back into the
        conversation.
EOF
        ;;
esac
exit 0
