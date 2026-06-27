import Foundation

/// The active receipts filter: an optional year and an optional tax line, applied
/// together (AND). Both nil means "all receipts".
struct ReceiptFilter: Hashable {
    var year: Int?
    var line: TaxLineCode?

    init(year: Int? = nil, line: TaxLineCode? = nil) {
        self.year = year
        self.line = line
    }

    var isActive: Bool { year != nil || line != nil }

    /// Navigation title, e.g. "All Receipts", "2026", "Medical expenses", or
    /// "Medical expenses · 2026".
    var title: String {
        let parts = [line?.category, year.map { String($0) }].compactMap { $0 }
        return parts.isEmpty ? "All Receipts" : parts.joined(separator: " · ")
    }

    /// Icon for placeholders.
    var systemImage: String {
        line?.systemImage ?? (year != nil ? "calendar" : "tray.full.fill")
    }

    func matches(_ receipt: Receipt) -> Bool {
        if let year, receipt.year != year { return false }
        if let line, !receipt.matchedLines.contains(where: { $0.code == line }) { return false }
        return true
    }
}

/// Sort orders offered in the list toolbar.
enum ReceiptSort: String, CaseIterable, Identifiable {
    case dateNewest, dateOldest, amountHigh, vendor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateNewest: "Newest First"
        case .dateOldest: "Oldest First"
        case .amountHigh: "Largest Amount"
        case .vendor: "Vendor"
        }
    }

    var systemImage: String {
        switch self {
        case .dateNewest, .dateOldest: "calendar"
        case .amountHigh: "dollarsign.circle"
        case .vendor: "textformat"
        }
    }

    func apply(_ receipts: [Receipt]) -> [Receipt] {
        receipts.sorted { lhs, rhs in
            // Still-processing receipts (which carry a placeholder "now" date) sink
            // below finished ones, so completed receipts fill the top of the list.
            if (lhs.status == .processing) != (rhs.status == .processing) {
                return lhs.status != .processing
            }
            return ordered(lhs, rhs)
        }
    }

    private func ordered(_ lhs: Receipt, _ rhs: Receipt) -> Bool {
        switch self {
        case .dateNewest:
            (lhs.date ?? lhs.createdAt) > (rhs.date ?? rhs.createdAt)
        case .dateOldest:
            (lhs.date ?? lhs.createdAt) < (rhs.date ?? rhs.createdAt)
        case .amountHigh:
            (lhs.total ?? 0) > (rhs.total ?? 0)
        case .vendor:
            (lhs.vendor ?? "").localizedCaseInsensitiveCompare(rhs.vendor ?? "") == .orderedAscending
        }
    }
}
