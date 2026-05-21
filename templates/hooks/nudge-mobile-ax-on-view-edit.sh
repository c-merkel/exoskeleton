#!/usr/bin/env bash
# templates/hooks/nudge-mobile-ax-on-view-edit.sh
#
# PreToolUse hook for Edit / Write / MultiEdit on iOS SwiftUI view files.
# Matches *View.swift / *Sheet.swift / *Flow.swift under any path that
# looks like an iOS app source root (heuristic: contains a *.xcodeproj
# ancestor, OR the path includes a top-level directory named ios-app /
# ios / app / App / Sources matching a Swift project).
#
# Emits a one-line nudge reminding the editor to add the canonical
# accessibility + Trace 4-point checklist:
#   1. .onAppear { Trace.viewAppear("ViewName", [ctx]) }
#   2. .ax("entity-surface") on every tappable
#   3. Trace.action("entity.verb", [ctx]) on every primary action
#   4. Trace.formSubmit("entity.form", [field-set ctx]) on save
#
# Never blocks — informational only. Skippable via the standard project
# skip flag: <PROJECT_SLUG>_SKIP_NUDGE_MOBILE_AX=1.
#
# Companion skill: /exoskeleton-mobile-ax (auto-surfaces in the skill list
# whenever you're working in an iOS / SwiftUI project).

set -u
[ "${<PROJECT_SLUG>_SKIP_NUDGE_MOBILE_AX:-0}" = "1" ] && exit 0

input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$path" ] && exit 0

# Only fire on Swift view-ish files
case "$path" in
    *.swift) ;;
    *) exit 0 ;;
esac
case "$path" in
    *View.swift|*Sheet.swift|*Flow.swift) ;;
    *) exit 0 ;;
esac

# Only when the file is plausibly in an iOS-app source tree (cheap heuristic).
# Look for an *.xcodeproj or Package.swift in any ancestor up to repo root.
dir=$(dirname "$path")
found_xcode=0
for _ in 1 2 3 4 5 6 7; do
    if [ -d "$dir" ] && ls "$dir"/*.xcodeproj >/dev/null 2>&1; then
        found_xcode=1; break
    fi
    if [ -f "$dir/Package.swift" ]; then
        found_xcode=1; break
    fi
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && break
    dir="$parent"
done
[ "$found_xcode" = "1" ] || exit 0

# Don't fire if the file already uses .ax( — already instrumented.
if [ -f "$path" ] && grep -q '\.ax(' "$path" 2>/dev/null; then
    exit 0
fi

cat <<'EOF' >&2
[nudge] Editing an iOS view that has no .ax(...) instrumentation yet.
        Every new view should include the 4-point checklist:
          1. .onAppear { Trace.viewAppear("ViewName", [ctx]) }
          2. .ax("entity-surface") on every tappable
          3. Trace.action("entity.verb", [ctx]) on every primary action
          4. Trace.formSubmit("entity.form", [field-set ctx]) on save
        Run /exoskeleton-mobile-ax for the canonical checklist + helpers.
        Without this the QA harness can't drive permutation tests by id
        — only by brittle coordinates + token-expensive screenshots.
EOF
exit 0
