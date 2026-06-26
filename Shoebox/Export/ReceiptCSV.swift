import Foundation

/// Builds a CSV of receipts with every field. RFC 4180 quoting, ISO dates, and
/// `.`-decimal numbers so it imports cleanly into Numbers / Excel / tax software.
/// (A UTF-8 BOM is added by `CSVDocument` so Excel reads accented text.)
enum ReceiptCSV {
    static let headers = [
        "Date", "Vendor", "Total", "Currency", "Tax",
        "Status", "Tax Lines", "Description",
        "Charity Registration", "Child Care Provider",
        "Validation Notes", "Added",
    ]

    static func make(from receipts: [Receipt]) -> String {
        var lines = [row(headers)]
        for receipt in receipts {
            lines.append(row([
                isoDate(receipt.date),
                receipt.vendor.sanitized ?? "",
                number(receipt.total),
                receipt.currency,
                number(receipt.taxAmount),
                receipt.status.label,
                taxLines(receipt),
                receipt.details.sanitized ?? "",
                receipt.charityRegistration.sanitized ?? "",
                receipt.providerName.sanitized ?? "",
                receipt.validationReasons.joined(separator: "; "),
                isoDate(receipt.createdAt),
            ]))
        }
        return lines.joined(separator: "\r\n")
    }

    // MARK: Fields

    private static func taxLines(_ receipt: Receipt) -> String {
        receipt.matchedLines.map { match in
            match.code == .other
                ? TaxLine.meta(for: .other).category
                : "\(match.code.rawValue) \(match.meta.category)"
        }.joined(separator: "; ")
    }

    private static func number(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value) // C locale → always "." decimal
    }

    private static func isoDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return isoFormatter.string(from: date)
    }

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: CSV encoding

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// RFC 4180: quote fields containing a comma, quote, or newline; double inner quotes.
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
