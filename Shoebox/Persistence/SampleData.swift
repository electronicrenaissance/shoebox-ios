import Foundation
import SwiftData

/// Seeds an in-memory store for SwiftUI previews so screens render with content
/// without touching CloudKit or running the model.
@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        for receipt in makeReceipts() {
            context.insert(receipt)
        }
        try? context.save()
    }

    static func makeReceipts() -> [Receipt] {
        func receipt(
            _ vendor: String,
            daysAgo: Int,
            total: Double,
            status: ReceiptStatus,
            lines: [TaxLineMatch],
            reasons: [String] = []
        ) -> Receipt {
            let r = Receipt(fileName: "\(vendor).jpg", mimeType: "image/jpeg", imageData: nil)
            r.vendor = vendor
            r.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)
            r.createdAt = r.date ?? .now
            r.total = total
            r.status = status
            r.matchedLines = lines
            r.validationReasons = reasons
            return r
        }

        return [
            receipt("Shoppers Drug Mart", daysAgo: 1, total: 48.20, status: .acceptable,
                    lines: [.init(code: .medical, confidence: .medium)]),
            receipt("Hope Mission", daysAgo: 3, total: 200, status: .needsAttention,
                    lines: [.init(code: .donations, confidence: .high)],
                    reasons: ["This looks like a store/sales slip, not an official donation receipt."]),
            receipt("Bright Beginnings Daycare", daysAgo: 14, total: 1450, status: .acceptable,
                    lines: [.init(code: .childCare, confidence: .high)]),
            receipt("The Globe and Mail", daysAgo: 27, total: 24, status: .acceptable,
                    lines: [.init(code: .digitalNews, confidence: .medium)]),
            {
                let r = Receipt(fileName: "scan.jpg", mimeType: "image/jpeg", imageData: nil)
                r.status = .processing
                return r
            }(),
        ]
    }
}
