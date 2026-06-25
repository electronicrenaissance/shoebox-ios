import SwiftUI
import SwiftData

/// Receipt detail: the captured image, the CRA validation result, matched
/// line(s), and extracted details, plus edit / retry / delete actions.
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                imagePreview

                if receipt.status == .processing {
                    processingCard
                } else {
                    validationCard
                    if !receipt.matchedLines.isEmpty { matchedLinesSection }
                    detailsSection
                }
            }
            .padding(16)
        }
        .background(Theme.paper)
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit details", systemImage: "pencil") { showingEdit = true }
                    if receipt.imageData != nil {
                        Button("Read again", systemImage: "arrow.clockwise") {
                            processor.reprocess(receipt, in: modelContext)
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ReceiptEditView(receipt: receipt)
        }
        .confirmationDialog("Delete this receipt?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the receipt and its image from your shoebox. This can't be undone.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var imagePreview: some View {
        if let data = receipt.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.line))
        } else {
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Color.white)
                .frame(height: 200)
                .overlay(Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(Theme.muted))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.line))
        }
    }

    private var processingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Reading this receipt on your device…")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }

    @ViewBuilder
    private var validationCard: some View {
        switch receipt.status {
        case .acceptable:
            ValidationCard(
                tone: .ok,
                icon: "checkmark.circle.fill",
                title: receipt.acceptabilityOverride ? "Marked CRA-ready by you" : "Looks CRA-ready",
                reasons: []
            )
        case .needsAttention:
            ValidationCard(
                tone: .warn,
                icon: "exclamationmark.triangle.fill",
                title: "Needs attention before you claim it",
                reasons: receipt.validationReasons
            )
        case .notATaxReceipt:
            ValidationCard(
                tone: .fail,
                icon: "xmark.circle",
                title: "This doesn't look like a tax receipt",
                reasons: receipt.validationReasons
            )
        case .failed:
            ValidationCard(
                tone: .fail,
                icon: "exclamationmark.triangle.fill",
                title: "Couldn't read this one",
                reasons: ["The photo may be too blurry. Edit the details by hand, or read it again."]
            )
        case .processing:
            EmptyView()
        }
    }

    private var matchedLinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Might apply to")
            ForEach(receipt.matchedLines, id: \.code) { match in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.meta.category).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                        if let line = match.meta.line {
                            let form = match.meta.form.map { " · \($0)" } ?? ""
                            Text("Line \(line)\(form)").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    Badge(tone: .muted, text: "\(match.confidence.rawValue) confidence")
                }
                .padding(14)
                .card()
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Details")
            VStack(spacing: 0) {
                DetailRow(label: "Payee", value: receipt.vendor ?? "—")
                Divider().overlay(Theme.line)
                DetailRow(label: "Date", value: receipt.longDateDisplay ?? "—")
                Divider().overlay(Theme.line)
                DetailRow(label: "Total", value: receipt.amountDisplay ?? "—")
                if let tax = receipt.taxAmount {
                    Divider().overlay(Theme.line)
                    DetailRow(label: "GST/HST", value: tax.formatted(.currency(code: receipt.currency)))
                }
                if let registration = receipt.charityRegistration {
                    Divider().overlay(Theme.line)
                    DetailRow(label: "Registration #", value: registration)
                }
            }
            .padding(.horizontal, 14)
            .card()
        }
    }

    private func delete() {
        modelContext.delete(receipt)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Small detail pieces

private struct ValidationCard: View {
    let tone: BadgeTone
    let icon: String
    let title: String
    let reasons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(tone.foreground)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tone.foreground)
            }
            ForEach(reasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(tone.foreground.opacity(0.6)).frame(width: 4, height: 4).padding(.top, 6)
                    Text(reason).font(.caption).foregroundStyle(tone.foreground.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(tone.foreground.opacity(0.2)))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .kerning(0.5)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}

/// Shared white card chrome.
private struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.line))
    }
}

extension View {
    func card() -> some View { modifier(Card()) }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(receipt: SampleData.makeReceipts()[1])
            .environment(ReceiptProcessor(reader: MockReceiptReader()))
            .modelContainer(ShoeboxStore.previewContainer())
    }
}
