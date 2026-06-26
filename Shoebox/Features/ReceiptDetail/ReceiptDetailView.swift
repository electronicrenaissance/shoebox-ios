import SwiftUI
import SwiftData

/// Receipt detail, built as a grouped `Form` so it reads natively on iPhone,
/// iPad, and Mac: a tappable image, the CRA verdict callout, matched line(s),
/// extracted details, and destructive/maintenance actions.
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @State private var showingEdit = false
    @State private var showingImage = false
    @State private var confirmingDelete = false

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
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
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
            LabeledContent("Payee", value: receipt.vendor ?? "—")
            LabeledContent("Date", value: receipt.longDateDisplay ?? "—")
            LabeledContent("Total", value: receipt.amountDisplay ?? "—")
            if let tax = receipt.taxAmount {
                LabeledContent("GST/HST", value: tax.formatted(.currency(code: receipt.currency)))
            }
            if let registration = receipt.charityRegistration {
                LabeledContent("Registration №", value: registration)
            }
            if let provider = receipt.providerName {
                LabeledContent("Provider", value: provider)
            }
        }
    }

    // MARK: Copy

    private var verdictHeadline: String {
        switch receipt.status {
        case .processing: "Reading on device…"
        case .acceptable: receipt.acceptabilityOverride ? "Marked CRA-ready by you" : "Looks CRA-ready"
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
