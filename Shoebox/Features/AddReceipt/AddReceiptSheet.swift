import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Bottom sheet offering the three capture paths (PRD FR-C1/C2/C3): scan with the
/// camera, pick an image, or import a PDF. Each path produces a `ReceiptInput`
/// handed back via `onCapture`, then the sheet dismisses.
struct AddReceiptSheet: View {
    var onCapture: (ReceiptInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPDFImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("We'll read it on your device and sort it by tax line automatically.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                CaptureOption(
                    icon: "camera",
                    title: "Take a photo",
                    subtitle: "Scan a paper receipt with the camera"
                ) { showingScanner = true }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    CaptureOptionLabel(
                        icon: "photo",
                        title: "Upload an image",
                        subtitle: "JPEG, PNG, HEIC or WebP"
                    )
                }

                CaptureOption(
                    icon: "doc.text",
                    title: "Upload a PDF",
                    subtitle: "e.g. an emailed donation receipt"
                ) { showingPDFImporter = true }

                Spacer()
            }
            .padding()
            .background(Theme.paper)
            .navigationTitle("Add a receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView(
                onScan: { data in
                    showingScanner = false
                    finish(data: data, fileName: "scan-\(timestamp).jpg", mimeType: "image/jpeg")
                },
                onCancel: { showingScanner = false }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task { await handlePhotoPick(newValue) }
        }
    }

    // MARK: Handlers

    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        // PhotosUI may hand back HEIC; normalize to JPEG for consistent OCR.
        let normalized = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
        finish(data: normalized, fileName: "image-\(timestamp).jpg", mimeType: "image/jpeg")
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        finish(data: data, fileName: url.lastPathComponent, mimeType: "application/pdf")
    }

    private func finish(data: Data, fileName: String, mimeType: String) {
        onCapture(ReceiptInput(data: data, mimeType: mimeType, fileName: fileName))
        dismiss()
    }

    private var timestamp: String {
        Date.now.formatted(.iso8601.year().month().day())
    }
}

// MARK: - Option row

private struct CaptureOption: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CaptureOptionLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

private struct CaptureOptionLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.brandDark)
                .frame(width: 40, height: 40)
                .background(Theme.brandLight, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }

            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.line))
    }
}

#Preview {
    Color.paper
        .sheet(isPresented: .constant(true)) {
            AddReceiptSheet { _ in }
        }
}

private extension Color {
    static let paper = Theme.paper
}
