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
