import Foundation
import FoundationModels

/// The structured result the on-device model produces for one receipt, using
/// Foundation Models **guided generation** (`@Generable` + `@Guide`). Guided
/// generation forces the model to emit a value that conforms to this schema, so
/// we get a typed object back instead of free text to parse.
///
/// Mirrors the `ReceiptReadResult` contract from the original backend
/// (extraction + CRA verdict + matched lines), now computed entirely on device.
@Generable
struct ReceiptReading {
    @Guide(description: "Vendor or payee name exactly as printed; null if not legible.")
    var vendor: String?

    @Guide(description: "Transaction or issue date in ISO 8601 yyyy-MM-dd; null if not legible.")
    var date: String?

    @Guide(description: "Grand total as a number, no currency symbol; null if not legible.")
    var total: Double?

    @Guide(description: "ISO currency code such as CAD or USD. Default to CAD when not shown.")
    var currency: String?

    @Guide(description: "GST/HST tax amount as a number, if the receipt shows it; otherwise null.")
    var taxAmount: Double?

    @Guide(description: "Short description of what was purchased or the service provided; null if unclear.")
    var details: String?

    @Guide(description: "Registered-charity BN/registration number for donation receipts; null if absent.")
    var charityRegistration: String?

    @Guide(description: "Child-care provider name for child-care receipts; null if not applicable.")
    var providerName: String?

    @Guide(description: "CRA acceptability verdict. Be conservative: prefer needsAttention when unsure.")
    var verdict: Verdict

    @Guide(description: "Specific reasons the receipt needs attention or is not a tax receipt. Empty when acceptable.")
    var reasons: [String]

    @Guide(description: "Every T1 tax line this receipt may apply to. May be empty.")
    var lines: [GeneratedMatch]

    /// CRA acceptability verdict (PRD FR-AI3). `failed` is never produced here —
    /// it is reserved for a thrown read (PRD FR-AI6).
    @Generable
    enum Verdict {
        case acceptable
        case needsAttention
        case notATaxReceipt
    }

    /// One matched line as the model returns it (codes/confidence as strings so
    /// the schema stays simple and robust); mapped to `TaxLineMatch` below.
    @Generable
    struct GeneratedMatch {
        @Guide(description: "CRA line code: one of 33099, 34900, 21400, 31350, 21900, 31285, 40900, or other.")
        var code: String

        @Guide(description: "Match confidence: high, medium, or low.")
        var confidence: String
    }
}

// MARK: - Mapping to the persistence/domain model

extension ReceiptReading {
    var status: ReceiptStatus {
        switch verdict {
        case .acceptable: .acceptable
        case .needsAttention: .needsAttention
        case .notATaxReceipt: .notATaxReceipt
        }
    }

    var parsedDate: Date? {
        guard let date else { return nil }
        return Self.isoDateFormatter.date(from: date)
    }

    /// The lines to auto-categorize this receipt under. We keep **only matches the
    /// model is highly confident about** — a real line (not `other`), known code,
    /// high confidence, de-duplicated. If nothing qualifies, we fall back to a
    /// single `Other / Uncategorized` entry so every receipt still files somewhere.
    var matchedLines: [TaxLineMatch] {
        var seen = Set<TaxLineCode>()
        let confident = lines.compactMap { raw -> TaxLineMatch? in
            guard
                let code = TaxLineCode(rawValue: raw.code), code != .other,
                Confidence(rawValue: raw.confidence.lowercased()) == .high,
                seen.insert(code).inserted
            else { return nil }
            return TaxLineMatch(code: code, confidence: .high)
        }
        return confident.isEmpty ? [TaxLineMatch(code: .other, confidence: .high)] : confident
    }

    /// A stable JSON snapshot for the immutable AI baseline (PRD FR-AI5).
    func asJSON() -> String {
        let payload: [String: Any] = [
            "vendor": vendor as Any,
            "date": date as Any,
            "total": total as Any,
            "currency": currency as Any,
            "taxAmount": taxAmount as Any,
            "details": details as Any,
            "charityRegistration": charityRegistration as Any,
            "providerName": providerName as Any,
            "verdict": String(describing: verdict),
            "reasons": reasons,
            "lines": lines.map { ["code": $0.code, "confidence": $0.confidence] },
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
