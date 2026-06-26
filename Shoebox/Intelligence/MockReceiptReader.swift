import Foundation

/// Deterministic reader with no model dependency — used in SwiftUI previews,
/// unit tests, and as a fallback on devices where Apple Intelligence is
/// unavailable so the capture/review loop still works (manual review/edit).
///
/// Keys off the filename so every branch is exercisable, mirroring the original
/// backend mock: `donation*` → needs-attention donations, `daycare*` → child
/// care, `blurry*` → throws → failed, otherwise → acceptable medical.
struct MockReceiptReader: ReceiptReader {
    /// Artificial delay to mimic on-device latency in previews/tests.
    var delay: Duration = .milliseconds(400)

    func read(_ input: ReceiptInput) async throws -> ReceiptReading {
        if delay > .zero { try await Task.sleep(for: delay) }

        let name = input.fileName.lowercased()

        if name.hasPrefix("blurry") {
            throw ReceiptReaderError.noTextFound
        }

        if name.hasPrefix("donation") {
            return ReceiptReading(
                vendor: "Hope Mission",
                date: "2026-06-12",
                total: 200,
                currency: "CAD",
                taxAmount: nil,
                details: "Cash donation",
                charityRegistration: nil,
                providerName: nil,
                verdict: .needsAttention,
                reasons: [
                    "This looks like a store/sales slip, not the official donation receipt a registered charity must issue.",
                    "No charity registration (BN) number was found.",
                    "Missing the words \"official receipt for income tax purposes\".",
                ],
                lines: [.init(code: "34900", confidence: "high")]
            )
        }

        if name.hasPrefix("daycare") {
            return ReceiptReading(
                vendor: "Bright Beginnings Daycare",
                date: "2026-06-01",
                total: 1450,
                currency: "CAD",
                taxAmount: nil,
                details: "Monthly child care",
                charityRegistration: nil,
                providerName: "Bright Beginnings Daycare Inc.",
                verdict: .acceptable,
                reasons: [],
                lines: [.init(code: "21400", confidence: "high")]
            )
        }

        return ReceiptReading(
            vendor: "Shoppers Drug Mart",
            date: "2026-06-14",
            total: 48.20,
            currency: "CAD",
            taxAmount: 2.30,
            details: "Prescription",
            charityRegistration: nil,
            providerName: nil,
            verdict: .acceptable,
            reasons: [],
            lines: [.init(code: "33099", confidence: "high")]
        )
    }
}
