import SwiftUI

/// One row in the receipts list: thumbnail, vendor + date, matched line / reason,
/// amount, and status pill — matching the design gallery list.
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ReceiptThumbnail(data: receipt.thumbnailData, isProcessing: receipt.status == .processing)

            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.vendorDisplay)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isMuted ? Theme.muted : Theme.ink)
                    .lineLimit(1)

                if let dateDisplay = receipt.dateDisplay {
                    Text(dateDisplay).font(.caption).foregroundStyle(Theme.muted)
                } else if receipt.status == .processing {
                    Text("Just now").font(.caption).foregroundStyle(Theme.muted)
                }

                if let match = receipt.matchedLines.first {
                    HStack(spacing: 6) {
                        TaxLineBadge(match: match)
                        if receipt.matchedLines.count > 1 {
                            Text("+\(receipt.matchedLines.count - 1) line")
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.top, 2)
                } else if let reason = receipt.validationReasons.first {
                    Text(reason)
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let amount = receipt.amountDisplay {
                    Text(amount).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                }
                StatusBadge(status: receipt.status)
            }
        }
        .padding(.vertical, 6)
    }

    private var isMuted: Bool {
        receipt.status == .processing || receipt.status == .failed
    }
}
