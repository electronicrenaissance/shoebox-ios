import SwiftUI

/// A receipt's thumbnail, or a system placeholder when there's no image yet
/// (a seeded or still-processing receipt). Native rounded-rect styling with a
/// hairline separator border.
struct ReceiptThumbnail: View {
    var data: Data?
    var isProcessing = false
    var size = CGSize(width: 46, height: 58)

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .imageScale(.large)
                    .foregroundStyle(.tertiary)
            }

            if isProcessing {
                Rectangle().fill(.ultraThinMaterial)
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
