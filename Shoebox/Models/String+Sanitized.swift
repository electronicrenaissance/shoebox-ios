import Foundation

extension String {
    /// Returns `nil` when the string is blank or a literal placeholder the
    /// on-device model sometimes emits as *text* (e.g. "null", "n/a") instead of a
    /// real null; otherwise the trimmed string. Keeps junk values out of the UI.
    var sanitized: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = ["null", "nil", "n/a", "na", "none", "unknown", "undefined", "-"]
        if trimmed.isEmpty || placeholders.contains(trimmed.lowercased()) { return nil }
        return trimmed
    }
}

extension Optional where Wrapped == String {
    /// `sanitized` lifted over an optional: `nil` stays `nil`, otherwise the
    /// wrapped string is sanitized.
    var sanitized: String? {
        switch self {
        case .some(let value): value.sanitized
        case .none: nil
        }
    }
}
