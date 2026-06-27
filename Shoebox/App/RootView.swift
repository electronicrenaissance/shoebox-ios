import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Top-level sections. A `TabView` renders these as a bottom tab bar on iPhone and
/// an adaptive sidebar on iPad/Mac (Apple's recommended top-level navigation).
enum AppSection: Hashable {
    case summary
    case receipts
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @State private var importer = ImportCoordinator()
    @State private var section: AppSection = .summary
    @State private var receiptsFilter = ReceiptFilter()
    @State private var receiptsSelection: Receipt?

    var body: some View {
        @Bindable var importer = importer

        TabView(selection: $section) {
            Tab("Summary", systemImage: "chart.pie.fill", value: AppSection.summary) {
                SummaryView(onSelectLine: { code, year in
                    receiptsFilter = ReceiptFilter(year: year, line: code)
                    receiptsSelection = nil
                    section = .receipts
                })
            }

            Tab("Receipts", systemImage: "tray.full.fill", value: AppSection.receipts) {
                NavigationSplitView {
                    ReceiptListView(filter: $receiptsFilter, selection: $receiptsSelection)
                } detail: {
                    DetailColumn(receipt: receiptsSelection) { receiptsSelection = nil }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(importer)
        // Import is presented and ingested once, at the root, so "+" works from any screen.
        .fullScreenCover(isPresented: $importer.isScanning) {
            DocumentScannerView(
                onScan: { data in
                    importer.isScanning = false
                    finishSingle(ingest(data: data, mimeType: "image/jpeg", fileName: "scan-\(stamp).jpg"))
                },
                onCancel: { importer.isScanning = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $importer.isPickingPhotos, selection: $importer.photoItems, matching: .images)
        .fileImporter(
            isPresented: $importer.isImportingPDFs,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handlePDFImport(result)
        }
        .onChange(of: importer.photoItems) { _, items in
            guard !items.isEmpty else { return }
            let pending = items
            importer.photoItems = []
            Task { await handlePhotoPicks(pending) }
        }
    }

    // MARK: Ingest (shared by every import path)

    @discardableResult
    private func ingest(data: Data, mimeType: String, fileName: String) -> Receipt? {
        let id = processor.ingest(
            ReceiptInput(data: data, mimeType: mimeType, fileName: fileName),
            into: modelContext
        )
        return modelContext.model(for: id) as? Receipt
    }

    /// Show the result of an import: jump to Receipts; open it if it was a single one.
    private func reveal(_ receipts: [Receipt]) {
        section = .receipts
        receiptsSelection = receipts.count == 1 ? receipts.first : nil
    }

    private func finishSingle(_ receipt: Receipt?) {
        reveal([receipt].compactMap { $0 })
    }

    private func handlePhotoPicks(_ items: [PhotosPickerItem]) async {
        // Load everything first, then ingest as one batch so the queue reads top-down.
        var datas: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            datas.append(UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data)
        }
        var ingested: [Receipt] = []
        for (index, data) in datas.enumerated() {
            if let receipt = ingest(data: data, mimeType: "image/jpeg", fileName: "photo-\(stamp)-\(index + 1).jpg") {
                ingested.append(receipt)
            }
        }
        reveal(ingested)
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        var ingested: [Receipt] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            if let receipt = ingest(data: data, mimeType: "application/pdf", fileName: url.lastPathComponent) {
                ingested.append(receipt)
            }
        }
        reveal(ingested)
    }

    private var stamp: String {
        Date.now.formatted(.iso8601.year().month().day())
    }
}

/// Detail pane content — the selected receipt, or a placeholder on iPad/Mac when
/// nothing is selected.
struct DetailColumn: View {
    let receipt: Receipt?
    let onDelete: () -> Void

    var body: some View {
        if let receipt {
            ReceiptDetailView(receipt: receipt, onDelete: onDelete)
        } else {
            ContentUnavailableView(
                "No Receipt Selected",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a receipt to see its details and CRA status.")
            )
        }
    }
}

#Preview {
    RootView()
        .environment(ReceiptProcessor(reader: MockReceiptReader()))
        .modelContainer(ShoeboxStore.previewContainer())
}
