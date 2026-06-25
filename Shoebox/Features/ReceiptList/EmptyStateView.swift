import SwiftUI

/// Shown when the user has no receipts yet.
struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.brand)

            VStack(spacing: 6) {
                Text("Your shoebox is empty")
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.ink)
                Text("Snap a photo or import an image or PDF. We'll read it on your device, check it's CRA-ready, and sort it by tax line.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onAdd) {
                Label("Add your first receipt", systemImage: "plus")
                    .fontWeight(.medium)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(onAdd: {})
        .background(Theme.paper)
}
