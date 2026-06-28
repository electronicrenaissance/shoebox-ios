import SwiftUI
import SwiftData

/// Receipt detail, built as a grouped `Form` so it reads natively on iPhone,
/// iPad, and Mac: a tappable image, the CRA verdict callout, matched line(s),
/// extracted details, and destructive/maintenance actions.
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    /// Called just before deletion so the container can clear its selection
    /// (resetting the detail pane and popping on iPhone).
    var onDelete: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @State private var showingEdit = false
    @State private var showingImage = false
    @State private var confirmingDelete = false

    // Download the original receipt file — Mac: Save panel; iPhone/iPad: Share sheet.
    #if targetEnvironment(macCatalyst)
    @State private var isSavingFile = false
    #else
    @State private var sharedFileURL: URL?
    #endif

    var body: some View {
        Form {
            if receipt.imageData != nil {
                Section {
                    imagePreview
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            verdictSection

            if !receipt.matchedLines.isEmpty {
                Section("Tax Lines") {
                    ForEach(receipt.matchedLines, id: \.code) { match in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.meta.category)
                                Text(match.code.lineSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: match.code.systemImage).foregroundStyle(.tint)
                        }
                    }
                }
            }

            detailsSection

            Section {
                if receipt.imageData != nil {
                    Button("Read Again", systemImage: "arrow.clockwise") {
                        processor.reprocess(receipt, in: modelContext)
                    }
                }
                Button("Delete Receipt", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(receipt.vendor ?? "Receipt")
        #if !targetEnvironment(macCatalyst)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                saveControl
                Button("Edit") { showingEdit = true }
            }
        }
        #if targetEnvironment(macCatalyst)
        .fileExporter(
            isPresented: $isSavingFile,
            document: ReceiptFileDocument(data: receipt.imageData ?? Data()),
            contentType: receipt.originalContentType,
            defaultFilename: receipt.fileName
        ) { _ in }
        #else
        .task(id: receipt.id) { sharedFileURL = receipt.writeTemporaryFile() }
        #endif
        .sheet(isPresented: $showingEdit) {
            ReceiptEditView(receipt: receipt)
        }
        .sheet(isPresented: $showingImage) {
            if let data = receipt.imageData, let image = UIImage(data: data) {
                ImageViewer(image: image)
            }
        }
        .confirmationDialog("Delete this receipt?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Receipt", role: .destructive, action: delete)
        } message: {
            Text("This removes the receipt and its image from your shoebox. This can’t be undone.")
        }
    }

    // MARK: Download

    /// Download/share the original receipt file. Hidden when there's no stored file.
    @ViewBuilder
    private var saveControl: some View {
        #if targetEnvironment(macCatalyst)
        Button("Save Receipt…", systemImage: "square.and.arrow.down") { isSavingFile = true }
            .disabled(receipt.imageData == nil)
        #else
        if let url = sharedFileURL {
            ShareLink(item: url, preview: SharePreview(receipt.fileName)) {
                Label("Save Receipt", systemImage: "square.and.arrow.up")
            }
        }
        #endif
    }

    // MARK: Sections

    private var imagePreview: some View {
        Button {
            showingImage = true
        } label: {
            if let data = receipt.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 320)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View receipt image")
    }

    @ViewBuilder
    private var verdictSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if receipt.status == .processing {
                        ProgressView()
                    } else {
                        Image(systemName: receipt.status.systemImage)
                            .font(.title2)
                            .foregroundStyle(receipt.status.tint)
                    }
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verdictHeadline)
                        .font(.headline)
                    if let subtitle = verdictSubtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            ForEach(receipt.validationReasons, id: \.self) { reason in
                Label(reason, systemImage: "circle.fill")
                    .labelStyle(BulletLabelStyle(tint: receipt.status.tint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Payee", value: receipt.vendor.sanitized ?? "")
            LabeledContent("Date", value: receipt.longDateDisplay ?? "")
            LabeledContent("Total", value: receipt.amountDisplay ?? "")
            if let tax = receipt.taxAmount {
                LabeledContent("GST/HST", value: tax.formatted(.currency(code: receipt.currency)))
            }
            if let registration = receipt.charityRegistration.sanitized {
                LabeledContent("Registration №", value: registration)
            }
            if let provider = receipt.providerName.sanitized {
                LabeledContent("Provider", value: provider)
            }
        }
    }

    // MARK: Copy

    private var verdictHeadline: String {
        switch receipt.status {
        case .processing: "Reading on device…"
        case .acceptable: "Looks CRA-ready"
        case .needsAttention: "Needs attention before you claim it"
        case .notATaxReceipt: "This doesn’t look like a tax receipt"
        case .failed: "Couldn’t read this one"
        }
    }

    private var verdictSubtitle: String? {
        switch receipt.status {
        case .acceptable: "It carries what the CRA looks for to support a claim."
        case .failed: "Edit the details by hand, or try reading it again."
        default: nil
        }
    }

    private func delete() {
        // Clear the selection first so the detail pane stops rendering this
        // receipt before it's removed from the store.
        onDelete()
        modelContext.delete(receipt)
        try? modelContext.save()
    }
}

/// Small bulleted-reason label: a tiny tinted dot + text.
private struct BulletLabelStyle: LabelStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(tint)
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(receipt: SampleData.makeReceipts()[1])
            .environment(ReceiptProcessor(reader: MockReceiptReader()))
            .modelContainer(ShoeboxStore.previewContainer())
    }
}
