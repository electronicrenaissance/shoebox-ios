import Foundation

/// A sidebar selection: the whole shoebox, the "needs attention" smart list, or a
/// single tax line.
enum ReceiptFilter: Hashable {
    case all
    case needsAttention
    case line(TaxLineCode)
    case year(Int)

    var title: String {
        switch self {
        case .all: "All Receipts"
        case .needsAttention: "Needs Attention"
        case .line(let code): code.category
        case .year(let year): String(year)
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .line(let code): code.systemImage
        case .year: "calendar"
        }
    }

    func matches(_ receipt: Receipt) -> Bool {
        switch self {
        case .all:
            return true
        case .needsAttention:
            return receipt.status.needsReview
        case .line(let code):
            return receipt.matchedLines.contains { $0.code == code }
        case .year(let year):
            return receipt.year == year
        }
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
        switch self {
        case .dateNewest:
            receipts.sorted { ($0.date ?? $0.createdAt) > ($1.date ?? $1.createdAt) }
        case .dateOldest:
            receipts.sorted { ($0.date ?? $0.createdAt) < ($1.date ?? $1.createdAt) }
        case .amountHigh:
            receipts.sorted { ($0.total ?? 0) > ($1.total ?? 0) }
        case .vendor:
            receipts.sorted { ($0.vendor ?? "").localizedCaseInsensitiveCompare($1.vendor ?? "") == .orderedAscending }
        }
    }
}
