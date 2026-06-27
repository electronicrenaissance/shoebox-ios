import Foundation

/// One tax line's roll-up for a year: how many receipts and their total amount.
struct TaxLineSummary: Identifiable, Sendable {
    let code: TaxLineCode
    let count: Int
    let total: Double

    var id: TaxLineCode { code }
}

/// Aggregates a year's receipts by tax line. Each receipt is counted under its
/// primary (first) matched line, so the per-line totals partition the year total.
/// Receipts still reading (no amount) contribute 0 to totals.
struct YearSummary: Sendable {
    let year: Int
    let receiptCount: Int
    let total: Double
    /// Lines that have at least one receipt this year, largest total first.
    let lines: [TaxLineSummary]

    init(receipts: [Receipt], year: Int) {
        self.year = year
        let yearReceipts = receipts.filter { $0.year == year }
        receiptCount = yearReceipts.count
        total = yearReceipts.reduce(0) { $0 + ($1.total ?? 0) }

        var byLine: [TaxLineCode: (count: Int, total: Double)] = [:]
        for receipt in yearReceipts {
            let code = receipt.matchedLines.first?.code ?? .other
            var entry = byLine[code] ?? (count: 0, total: 0)
            entry.count += 1
            entry.total += receipt.total ?? 0
            byLine[code] = entry
        }
        lines = byLine
            .map { TaxLineSummary(code: $0.key, count: $0.value.count, total: $0.value.total) }
            .sorted { ($0.total, $1.count) > ($1.total, $0.count) }
    }
}
