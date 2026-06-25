import SwiftUI

/// Renders a receipt's thumbnail, or a stylized placeholder when there's no
/// image yet (e.g. a `processing` or seeded receipt).
struct ReceiptThumbnail: View {
    var data: Data?
    var isProcessing: Bool = false

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
        .opacity(isProcessing ? 0.6 : 1)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(Theme.line).frame(width: 24, height: 3)
            Capsule().fill(Theme.line).frame(width: 16, height: 3)
            Spacer(minLength: 0)
            Capsule().fill(Theme.brand.opacity(0.3)).frame(width: 20, height: 3)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}
