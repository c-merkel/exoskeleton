# iOS Accessibility Identifier Naming Convention

**Goal:** every control in the app that a user can tap / fill / select carries a stable, machine-readable identifier so the programmatic QA harness (`qa/smoke-ios-flows.sh`) can drive any flow without coordinates or screenshots — AND so real VoiceOver users get good screen-reader output.

---

## Format

```
<entity>-<surface>[-<context>]
```

- **`<entity>`** — singular, lower-case, hyphen-separated. Match the iOS struct name's lower form. Examples (substitute your project's entities): `customer`, `order`, `invoice`, `line-item`, `tab`, `fab`, `nav`.
- **`<surface>`** — what the control IS. Standard verbs/nouns:
  - `list`, `row`, `card`, `detail`
  - `edit`, `create`, `delete`, `save`, `cancel`
  - `field-<fieldName>` (camelCase, matches the iOS struct field name — e.g. `field-firstName`, `field-displayOrder`)
  - `picker-<name>`, `toggle-<name>`, `chip-<name>`
  - `btn` (always `-btn` suffix for buttons that aren't covered by the verbs above)
  - `tab-<name>`
- **`<context>`** — optional. Use for row instances: `customer-row-{id}`. Or for variants: `customer-edit-save-btn-primary` vs `customer-edit-cancel-btn`.

---

## Examples

| Control | Identifier |
|---|---|
| Tabs (TabView items) | `tab-home`, `tab-clients`, `tab-orders`, `tab-more` |
| FAB | `fab-button`, `fab-chip-newOrder`, `fab-chip-newCustomer` |
| List row instance | `customer-row-12`, `order-row-203` |
| List header / segmented picker | `customer-list-mode-picker`, `order-list-stage-pills` |
| Detail screen | `customer-detail`, `order-detail` |
| Edit sheet text field | `customer-edit-field-firstName`, `order-edit-field-notes` |
| Edit sheet selector | `customer-edit-picker-source` |
| Save / cancel button | `customer-edit-save-btn`, `customer-edit-cancel-btn` |
| Multi-step wizard step indicator | `order-wizard-step-1`, `order-wizard-step-customer`, `order-wizard-next-btn` |
| Line-item row | `order-line-item-row-{id}` |

---

## Helper

Use the `.ax(_:)` modifier from `Core/Accessibility.swift` rather than `.accessibilityIdentifier(_:)` directly:

```swift
Button("Save") { ... }.ax("customer-edit-save-btn")
```

`.ax(_:)` sets BOTH `.accessibilityIdentifier()` (for tests) AND `.accessibilityLabel()` (for VoiceOver) from a single identifier. The label is auto-derived by replacing `-` with spaces ("Customer edit save btn") so screen readers get human-ish output even before someone writes a proper label override.

If you need a different VoiceOver label vs the test identifier:

```swift
.ax("customer-edit-save-btn", label: "Save customer")
```

---

## Trace events on action

Every primary action (Save, Submit, Delete, etc.) emits a `Trace.action(...)` event so the harness can verify "did the action fire?" without reading the next view's state:

```swift
Button {
    Trace.action("customer.save", ["id": customer.id, "name_changed": originalName != name])
    Task { await save() }
} label: { Text("Save") }
```

Form submits aggregate via `Trace.formSubmit("customer.edit", ["field_count": fields.count])`.

Naming convention for action keys: `<entity>.<verb>` (period, NOT hyphen — distinguishes action keys from accessibility identifiers).

---

## When NOT to add an identifier

- Decorative-only views (separators, spacer, background gradients)
- Static text that isn't interactive AND isn't load-bearing for QA (titles, body copy — VoiceOver picks these up from the text content)
- Internal helper Views that wrap a single instrumented child (the child carries the id)

When in doubt: add it. The cost is one line; the upside is a programmatic handle the harness can use.

---

## Coverage tracker

`qa/iOS_AX_COVERAGE.md` lists every view-level surface and whether it's instrumented. Update when a view gets its first identifier OR when a flow's smoke script lands. Don't let it drift.

---

## Compatibility quirks

- **SwiftUI TabView** — `.accessibilityIdentifier` on `.tabItem` DOES NOT propagate to UIKit UITabBar buttons. Coordinate fallback only. Inner SwiftUI views respect the modifier normally.
- **NavigationLink** — set the identifier on the LABEL view, not the link, for taps to resolve cleanly.
- **List rows** — set the identifier on the row's outermost view inside `ForEach`. SwiftUI list cell wrapping otherwise eats it.
- **UIViewRepresentable wrappers** (PencilKit, MapKit, custom UIKit) need an explicit `axId:` parameter plumbed through to the wrapped UIView's `accessibilityIdentifier`.
