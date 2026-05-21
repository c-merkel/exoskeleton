---
name: exoskeleton-mobile-ax
description: When working in an iOS / SwiftUI project, this skill installs and maintains the canonical accessibility-identifier + diagnostic-trace layer that makes every user flow programmatically drivable. Eliminates brittle coordinate taps and token-expensive screenshot loops from your QA harness. Auto-surfaces whenever iOS view files are being edited.
---

# Exoskeleton — Mobile AX (programmatic-debuggability layer for iOS apps)

A consumer-grade convention + primitive bundle that turns any SwiftUI app into a programmatically QA-able surface. Born in the FMM consumer project (full app sweep 2026-05-20 → 2026-05-21, ~250 identifiers across ~25 view files), generalised for the public exoskeleton.

## When to invoke

- A consumer project is starting iOS / SwiftUI work (detected by `*.xcodeproj` or `Package.swift` + Swift sources). The exoskeleton's bootstrap should announce this skill at first iOS turn.
- A new SwiftUI view is being added and the operator wants the canonical 4-point checklist applied.
- The `nudge-mobile-ax-on-view-edit.sh` PreToolUse hook fires on an Edit/Write of `*View.swift`/`*Sheet.swift`/`*Flow.swift` and the operator wants the full checklist.
- An existing app's QA harness is stuck taking screenshots / tapping coordinates and the operator wants to upgrade.

## What the layer gives you

- **Tap any button / list row by id**: `xcodebuildmcp ui-automation tap --id "customer-row-12"`
- **Fill any TextField / Picker by id**: same, just target the field id
- **Verify which view is on screen** via `Trace.viewAppear` events in `<app-sandbox>/Documents/sync-trace.jsonl`
- **Verify any primary action fired** via `Trace.action` events
- **Verify any form save's full field-set** via `Trace.formSubmit` events
- **Zero coordinate guessing, zero screenshot taking** for state inspection
- **Real VoiceOver users benefit too** — the `.ax(_:)` helper sets both `accessibilityIdentifier` AND `accessibilityLabel` from one call

Token math: a single screenshot read into the conversation is ~30K tokens. A snapshot-ui call piped to jq is ~1-2K. With this layer in place, a full QA flow that previously needed 8 screenshots can do its job with a handful of CLI calls.

## The 4 things every iOS view needs

### 1. `.onAppear { Trace.viewAppear("ViewName", [state ctx]) }`

PascalCase view name. Context is primitive-only state (counts, mode, id, has_data flags). Never PII.

```swift
.onAppear { Trace.viewAppear("CustomerDetail", ["id": c.id, "has_bookings": (c.bookings?.count ?? 0)]) }
```

### 2. `.ax("entity-surface[-context]")` on every tappable thing

Tabs, FAB, buttons, list rows, every TextField / Picker / Toggle / Stepper. Naming: `<entity>-<surface>[-<context>]` per the naming convention doc the install lays down.

```swift
Button("Save") { ... }.ax("customer-edit-save-btn")
TextField("Email", text: $email).ax("customer-edit-field-email")
ForEach(customers) { c in CustomerRow(c).ax("customer-row-\(c.id)") }
```

### 3. `Trace.action(...)` on every primary action

Save, delete, submit, send, convert, archive, promote, open-sheet. Naming: `<entity>.<verb>` (period, NOT hyphen — distinguishes from AX ids).

```swift
Button {
    Trace.action("customer.save", ["id": customer.id])
    Task { await save() }
} label: { ... }
```

### 4. `Trace.formSubmit(...)` on every form save

Comprehensive ctx of which fields were set so the harness can verify the right body was assembled.

```swift
Trace.formSubmit("customer.edit", [
    "id": customer.id, "is_create": customer.id == 0,
    "first_name_set": !firstName.isEmpty, "email_set": !email.isEmpty,
])
```

## What this skill installs

When the operator says "yes, set up the mobile AX layer", drop these files into the consumer's iOS source tree (paths adapt to the consumer's layout — ask if `ios-app/<App>/Core/` doesn't fit):

| Asset | Destination | Source template |
|---|---|---|
| `.ax(_:)` View modifier helper | `<iOS-root>/Core/Accessibility.swift` | `templates/mobile-ax/Accessibility.swift` |
| `Trace` extensions (viewAppear/viewDisappear/action/formSubmit) | append to existing `<iOS-root>/Core/Trace.swift` OR create if absent | `templates/mobile-ax/Trace.swift.snippet` |
| Naming convention doc | `docs/ios-ax-naming-convention.md` | `templates/mobile-ax/ios-ax-naming-convention.md` |
| Coverage tracker (load-bearing ledger) | `qa/iOS_AX_COVERAGE.md` | `templates/mobile-ax/iOS_AX_COVERAGE.md.template` |
| Smoke-test driver | `qa/smoke-ios-flows.sh` | `templates/mobile-ax/smoke-ios-flows.sh.template` |
| PreToolUse nudge hook | `.claude/hooks/nudge-mobile-ax-on-view-edit.sh` | `templates/hooks/nudge-mobile-ax-on-view-edit.sh` |
| Sim-MCP-vs-CLI nudge hook | `.claude/hooks/nudge-ios-sim-mcp.sh` | `templates/hooks/nudge-ios-sim-mcp.sh` |

Then register both hooks in the consumer's `.claude/settings.json` PreToolUse array.

## Walkthrough

### Step 1 — Detect the iOS source root

```bash
XCODEPROJ=$(find . -maxdepth 4 -name '*.xcodeproj' -type d 2>/dev/null | head -1)
[ -z "$XCODEPROJ" ] && PKG=$(find . -maxdepth 3 -name 'Package.swift' 2>/dev/null | head -1)
IOS_ROOT=$(dirname "$XCODEPROJ")
```

Confirm with the operator: "iOS source root looks like `<path>`. The helper will land at `<path>/Core/Accessibility.swift`. OK?"

### Step 2 — Drop primitives

`cp` each template file into the destination. Substitute the consumer's project slug into the hook files (`<PROJECT_SLUG>` placeholder).

### Step 3 — Adopt Accessibility.swift in the Xcode project

If the project uses a `.xcodeproj`, the file must be added to the build phase (file references + PBXSourcesBuildPhase). For a new project, Xcode auto-detects; for an established project, the operator may need to drag the file into the navigator. Flag this clearly.

### Step 4 — Append Trace extensions

If `<iOS-root>/Core/Trace.swift` exists, append the snippet. If not, create from the template. The snippet adds `viewAppear`, `viewDisappear`, `action`, `formSubmit` APIs on top of whatever `log` impl the project already has — adapt the underlying `log` call if the project uses a different logger.

### Step 5 — Register hooks

Add both hook entries to the consumer's `.claude/settings.json` under `hooks.PreToolUse`. Use `Edit` to splice them into the existing array (don't rewrite the file).

### Step 6 — Bless the coverage tracker

The empty `qa/iOS_AX_COVERAGE.md` is a ledger the operator will update as each view is instrumented. Explain its purpose: "When a view goes ✅ across viewAppear / .ax / Action-events, its smoke script can drive the flow end-to-end. Don't let it drift."

### Step 7 — Walkthrough one example view

To anchor the pattern, ask the operator to pick one existing view (or a stub). Show the four-point instrumentation applied to it. Build green. That's the reference for everything else.

## Known SwiftUI quirks

- **TabView .tabItem .accessibilityIdentifier doesn't reach UITabBar buttons** (UIKit bridging gap). Falls through to coordinates for tab nav. Inner SwiftUI content inside the tab respects the modifier normally.
- **UIViewRepresentable wrappers** (PencilKit canvases, custom map views, etc.) need an explicit `axId:` parameter plumbed through to the wrapped UIView's `accessibilityIdentifier`.
- **NavigationLink** — set the identifier on the LABEL view, not the link, for taps to resolve cleanly.
- **List rows** — set the identifier on the row's outermost view inside `ForEach`. SwiftUI list-cell wrapping otherwise eats it.

## Why this matters (one-liner for the operator)

Without this layer, the agent's QA harness:
- Taps by coordinates (brittle — breaks on screen rotation, tab-bar offsets, Dynamic Type, device class)
- Takes screenshots and parses them visually (~30K tokens per shot)
- Guesses at app state from network traffic (incomplete — misses local-only form drafts)

With it: bash-scriptable, deterministic, and uses ~10× fewer tokens per test.

## Reference implementation

The pattern was born + battle-tested in `github.com/c-merkel/FMM-canonical` (private). For a public reference, see the FMM session 2026-05-21 handoff and the assets at `templates/mobile-ax/` in this exoskeleton bundle.

## When this skill is NOT the right tool

- The project is **not** an iOS / SwiftUI app — Android / Flutter / RN would need their own equivalents. (Flag as future work; the same pattern generalises.)
- The project's QA harness already uses Xcode UI tests with view-controller-level XCUIElement queries and the operator doesn't want a second layer. (Rare — the two coexist fine.)
