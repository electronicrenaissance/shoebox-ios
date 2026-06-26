import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

/// The middle column: the user's receipts for the selected filter, searchable and
/// sortable, with an Add menu that scans / picks / imports. Selecting a row drives
/// the detail column (and pushes on iPhone).
struct ReceiptListView: View {
    let filter: ReceiptFilter
    @Binding var selection: Receipt?

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @Query(sort: \Receipt.createdAt, order: .reverse) private var allReceipts: [Receipt]

    @State private var searchText = ""
    @State private var sort: ReceiptSort = .dateNewest

    // Capture presentation
    @State private var isScanning = false
    @State private var isPickingPhoto = false
    @State private var isImportingPDF = false
    @State private var photoItems: [PhotosPickerItem] = []

    // Export (Mac uses a Save panel; iPhone/iPad use a Share sheet)
    #if targetEnvironment(macCatalyst)
    @State private var exportDocument: CSVDocument?
    @State private var isExporting = false
    #endif

    private var receipts: [Receipt] {
        var list = allReceipts.filter(filter.matches)
        if !searchText.isEmpty {
            list = list.filter { receipt in
                [receipt.vendor, receipt.details, receipt.matchedLines.first?.meta.category]
                    .compactMap { $0 }
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return sort.apply(list)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(receipts) { receipt in
                ReceiptRow(receipt: receipt)
                    .tag(receipt)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete(receipt) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu { contextMenu(for: receipt) }
            }
        }
        .listStyle(.inset)
        .navigationTitle(filter.title)
        .searchable(text: $searchText, prompt: "Search receipts")
        .overlay { emptyState }
        .toolbar { toolbar }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScannerView(
                onScan: { data in
                    isScanning = false
                    selection = ingest(data: data, mimeType: "image/jpeg", fileName: "scan-\(stamp).jpg")
                },
                onCancel: { isScanning = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItems, matching: .images)
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handlePDFImport(result)
        }
        #if targetEnvironment(macCatalyst)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .focusedValue(\.exportAction, receipts.isEmpty ? nil : {
            exportDocument = CSVDocument(text: ReceiptCSV.make(from: receipts))
            isExporting = true
        })
        #endif
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            let pending = items
            photoItems = []
            Task { await handlePhotoPicks(pending) }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            exportControl

            Menu {
                Picker("Sort By", selection: $sort) {
                    ForEach(ReceiptSort.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Menu {
                if VNDocumentCameraViewController.isSupported {
                    Button("Scan Document", systemImage: "doc.viewfinder") { isScanning = true }
                }
                Button("Choose Photos", systemImage: "photo.on.rectangle") { isPickingPhoto = true }
                Button("Import PDFs", systemImage: "doc.badge.plus") { isImportingPDF = true }
            } label: {
                Label("Add Receipt", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private var exportFilename: String { "Shoebox - \(filter.title)" }

    /// Mac: a Save panel via `.fileExporter`. iPhone/iPad: the system Share sheet.
    @ViewBuilder
    private var exportControl: some View {
        #if targetEnvironment(macCatalyst)
        Button("Export", systemImage: "square.and.arrow.up") {
            exportDocument = CSVDocument(text: ReceiptCSV.make(from: receipts))
            isExporting = true
        }
        .disabled(receipts.isEmpty)
        #else
        ShareLink(
            item: CSVExport(text: ReceiptCSV.make(from: receipts), filename: exportFilename),
            preview: SharePreview(exportFilename)
        ) {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(receipts.isEmpty)
        #endif
    }

    // MARK: Empty states

    @ViewBuilder
    private var emptyState: some View {
        if receipts.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if allReceipts.isEmpty {
                ContentUnavailableView {
                    Label("Your Shoebox Is Empty", systemImage: "doc.text.viewfinder")
                } description: {
                    Text("Scan or import a receipt. Shoebox reads it on your device, checks it’s CRA-ready, and files it by tax line.")
                } actions: {
                    Button("Add a Receipt") { isPickingPhoto = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView(
                    "Nothing Here Yet",
                    systemImage: filter.systemImage,
                    description: Text("No receipts match “\(filter.title)”.")
                )
            }
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private func contextMenu(for receipt: Receipt) -> some View {
        if receipt.imageData != nil {
            Button("Read Again", systemImage: "arrow.clockwise") {
                processor.reprocess(receipt, in: modelContext)
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { delete(receipt) }
    }

    // MARK: Actions

    private func delete(_ receipt: Receipt) {
        if selection == receipt { selection = nil }
        modelContext.delete(receipt)
        try? modelContext.save()
    }

    /// Persist one capture and return the new receipt (for selection).
    @discardableResult
    private func ingest(data: Data, mimeType: String, fileName: String) -> Receipt? {
        let id = processor.ingest(
            ReceiptInput(data: data, mimeType: mimeType, fileName: fileName),
            into: modelContext
        )
        return modelContext.model(for: id) as? Receipt
    }

    private func handlePhotoPicks(_ items: [PhotosPickerItem]) async {
        // Load everything first, then ingest as one batch so the queue reads them
        // in list order (top-down).
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
        // Auto-open only a single import; a batch stays on the list to watch it fill.
        if ingested.count == 1 { selection = ingested.first }
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
        if ingested.count == 1 { selection = ingested.first }
    }

    private var stamp: String {
        Date.now.formatted(.iso8601.year().month().day())
    }
}
