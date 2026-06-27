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

    /// Short label for the status indicator.
    var label: String {
        switch self {
        case .processing: "Reading"
        case .acceptable: "CRA-ready"
        case .needsAttention: "Needs attention"
        case .notATaxReceipt: "Not a tax receipt"
        case .failed: "Couldn’t read"
        }
    }

    var systemImage: String {
        switch self {
        case .processing: "clock"
        case .acceptable: "checkmark.seal.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .notATaxReceipt: "xmark.seal.fill"
        case .failed: "exclamationmark.octagon.fill"
        }
    }

    /// Semantic tint — adapts to light/dark automatically.
    var tint: Color {
        switch self {
        case .processing: .secondary
        case .acceptable: .green
        case .needsAttention: .orange
        case .notATaxReceipt, .failed: .red
        }
    }
}
