import Foundation
import FoundationModels

/// Chooses the right `ReceiptReader` for the current device. When Apple
/// Intelligence is available we use the on-device model; otherwise we fall back
/// to the mock so the capture/manual-edit loop still works (the user just won't
/// get automatic extraction). PRD: graceful degradation when AI is unavailable.
enum ReceiptReaderFactory {
    static func make() -> ReceiptReader {
        switch SystemLanguageModel.default.availability {
        case .available:
            return FoundationModelsReceiptReader()
        case .unavailable:
            return MockReceiptReader(delay: .zero)
        }
    }

    /// Human-readable reason Apple Intelligence is unavailable, for a settings/UI
    /// hint; `nil` when it is available.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device doesn't support Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Turn on Apple Intelligence in Settings to read receipts automatically."
            case .modelNotReady:
                return "Apple Intelligence is still downloading. Try again shortly."
            @unknown default:
                return "Apple Intelligence is unavailable right now."
            }
        }
    }
}
