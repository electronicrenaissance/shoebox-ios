import SwiftUI

/// One row in the receipts list: thumbnail, vendor + context line, amount, and
/// status. Styled with system typography and semantic colors so it looks at home
/// in a plain/inset `List` on every platform.
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            ReceiptThumbnail(data: receipt.thumbnailData, isProcessing: receipt.status == .processing)

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.vendorDisplay)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isDimmed ? .secondary : .primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let amount = receipt.amountDisplay {
                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                StatusLabel(status: receipt.status, compact: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var isDimmed: Bool {
        receipt.status == .processing || receipt.status == .failed
    }

    private var subtitle: String {
        switch receipt.status {
        case .processing:
            return "Reading on device…"
        case .failed:
            return receipt.validationReasons.first ?? "Tap to edit by hand"
        default:
            var parts: [String] = []
            if let date = receipt.dateDisplay { parts.append(date) }
            if let line = receipt.matchedLines.first { parts.append(line.meta.category) }
            return parts.isEmpty ? "No details" : parts.joined(separator: " · ")
        }
    }
}
