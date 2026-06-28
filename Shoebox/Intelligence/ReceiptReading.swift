import Foundation
import FoundationModels

/// Call 1 — extraction. A small, single-purpose schema so the on-device model
/// reliably fills in the fields (a combined extract+validate+match call overloads
/// the small model and it drops fields).
@Generable
struct ReceiptExtraction {
    @Guide(description: "The business or charity name printed on the receipt; null only if truly absent.")
    var vendor: String?

    @Guide(description: "Issue/transaction date as ISO 8601 yyyy-MM-dd; null if not present.")
    var date: String?

    @Guide(description: "Grand total as a number, no currency symbol; null if not present.")
    var total: Double?

    @Guide(description: "ISO currency code such as CAD or USD. Default to CAD when not shown.")
    var currency: String?

    @Guide(description: "GST/HST tax amount as a number if the receipt shows it; otherwise null.")
    var taxAmount: Double?

    @Guide(description: "Short description of what was purchased or donated; null if unclear.")
    var details: String?

    @Guide(description: "Charity registration number in the format 9 digits + RR + 4 digits (e.g. 123456789 RR0001); null if no such number is present. Never a phone number.")
    var charityRegistration: String?

    @Guide(description: "Child-care provider name; null if not applicable.")
    var providerName: String?
}

/// Call 2 — classification. Picks the single best tax line plus the CRA verdict.
/// A single-line output (not free multi-label) avoids the model tagging every line.
@Generable
struct ReceiptClassification {
    @Guide(description: "The single best-matching T1 line code: 33099, 34900, 21400, 31350, 21900, 31285, 40900, or other.")
    var line: String

    @Guide(description: "Confidence the line is correct: high, medium, or low.")
    var confidence: String

    @Guide(description: "CRA acceptability verdict. Be conservative: prefer needsAttention when unsure.")
    var verdict: Verdict

    @Guide(description: "Specific reasons the receipt needs attention or is not a tax receipt. Empty when acceptable.")
    var reasons: [String]

    @Generable
    enum Verdict {
        case acceptable
        case needsAttention
        case notATaxReceipt
    }
}

/// The merged result the reader returns (built from the two calls, or directly by
/// the mock). The route maps it onto the receipt and keeps `asJSON()` as the raw
/// AI baseline (PRD FR-AI5).
struct ReceiptReading {
    var vendor: String?
    var date: String?
    var total: Double?
    var currency: String?
    var taxAmount: Double?
    var details: String?
    var charityRegistration: String?
    var providerName: String?

    /// CRA verdict + lifecycle. `failed` is never produced here — it's reserved for
    /// a thrown read (PRD FR-AI6).
    var status: ReceiptStatus
    var reasons: [String]

    /// Single best-matching line and how confident we are (`nil` line → uncategorized).
    var line: TaxLineCode?
    var lineConfidence: Confidence

    var parsedDate: Date? {
        guard let date else { return nil }
        return Self.isoDateFormatter.date(from: date)
    }

    /// We file the receipt under its line only when the model is **highly
    /// confident** about a real line; otherwise it falls back to `Other`.
    var matchedLines: [TaxLineMatch] {
        if let line, line != .other, lineConfidence == .high {
            return [TaxLineMatch(code: line, confidence: .high)]
        }
        return [TaxLineMatch(code: .other, confidence: .high)]
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
            "status": status.rawValue,
            "reasons": reasons,
            "line": line?.rawValue as Any,
            "lineConfidence": lineConfidence.rawValue,
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

extension ReceiptClassification.Verdict {
    var status: ReceiptStatus {
        switch self {
        case .acceptable: .acceptable
        case .needsAttention: .needsAttention
        case .notATaxReceipt: .notATaxReceipt
        }
    }
}

extension ReceiptExtraction {
    /// Used when the extraction call is refused — leaves everything for the user.
    static var empty: ReceiptExtraction {
        ReceiptExtraction(
            vendor: nil, date: nil, total: nil, currency: nil,
            taxAmount: nil, details: nil, charityRegistration: nil, providerName: nil
        )
    }
}

extension ReceiptClassification {
    /// Used when the classify call is refused — files the receipt for manual review.
    static var refused: ReceiptClassification {
        ReceiptClassification(
            line: "other",
            confidence: "low",
            verdict: .needsAttention,
            reasons: ["Shoebox couldn’t automatically check this receipt — review the details and set the tax line."]
        )
    }
}
