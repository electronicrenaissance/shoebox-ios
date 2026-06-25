import SwiftUI

/// Lifecycle + CRA-acceptability of a receipt. `processing` while the on-device
/// model reads it; the three verdicts are the validation result (PRD FR-AI3);
/// `failed` means the read threw but the receipt is still saved and editable by
/// hand (PRD FR-AI6).
enum ReceiptStatus: String, Codable, Sendable {
    case processing
    case acceptable
    case needsAttention = "needs_attention"
    case notATaxReceipt = "not_a_tax_receipt"
    case failed

    /// Short label for the status pill.
    var label: String {
        switch self {
        case .processing: "Reading…"
        case .acceptable: "CRA-ready"
        case .needsAttention: "Needs attention"
        case .notATaxReceipt: "Not a tax receipt"
        case .failed: "Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .processing: "arrow.triangle.2.circlepath"
        case .acceptable: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .notATaxReceipt: "xmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    /// Tint used by `StatusBadge`, mapping onto the design system tones.
    var tone: BadgeTone {
        switch self {
        case .processing: .muted
        case .acceptable: .ok
        case .needsAttention: .warn
        case .notATaxReceipt, .failed: .fail
        }
    }
}
