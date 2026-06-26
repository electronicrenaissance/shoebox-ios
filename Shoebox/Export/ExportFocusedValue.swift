import SwiftUI

/// Bridges the Mac menu-bar "Export…" command to the focused window's list, which
/// publishes its export action as a focused value.
struct ExportActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportAction: (() -> Void)? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }
}
