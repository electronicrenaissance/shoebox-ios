import SwiftUI

/// The receipt's status as a tinted SF Symbol + label. `processing` shows a live
/// spinner. Uses semantic colors so it adapts to light/dark.
struct StatusLabel: View {
    let status: ReceiptStatus
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if status == .processing {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: status.systemImage)
                    .imageScale(compact ? .small : .medium)
            }
            Text(status.label)
        }
        .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
        .foregroundStyle(status.tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.label)
    }
}

/// A small line chip, e.g. a tinted "Medical" tag with its symbol.
struct TaxLineChip: View {
    let code: TaxLineCode

    var body: some View {
        Label(code.category, systemImage: code.systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusLabel(status: .acceptable)
        StatusLabel(status: .needsAttention)
        StatusLabel(status: .processing)
        StatusLabel(status: .failed, compact: true)
        TaxLineChip(code: .donations)
    }
    .padding()
}
