// Accessibility.swift — `.ax(_:)` View modifier helper
//
// Sets both `.accessibilityIdentifier(_:)` (for programmatic QA harness
// targeting via `xcodebuildmcp ui-automation tap --id "..."`) and
// `.accessibilityLabel(_:)` (for VoiceOver users) from a single call.
//
// Naming convention: see docs/ios-ax-naming-convention.md.
//
// Usage:
//     Button("Save") { ... }.ax("customer-edit-save-btn")
//
// If you need different test id vs VoiceOver label:
//     .ax("customer-edit-save-btn", label: "Save customer")

import SwiftUI

extension View {
    /// Apply both an accessibility identifier (for tests) and an
    /// accessibility label (for VoiceOver) to this view.
    ///
    /// The label is derived from the identifier by replacing `-` with
    /// spaces and capitalising the first letter, unless an explicit
    /// `label` is passed.
    @ViewBuilder
    func ax(_ id: String, label: String? = nil) -> some View {
        self
            .accessibilityIdentifier(id)
            .accessibilityLabel(label ?? Self._axLabelFrom(id))
    }

    fileprivate static func _axLabelFrom(_ id: String) -> String {
        let spaced = id.replacingOccurrences(of: "-", with: " ")
        guard let first = spaced.first else { return spaced }
        return String(first).uppercased() + spaced.dropFirst()
    }
}
