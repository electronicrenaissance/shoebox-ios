import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Receipts tab: the user's receipts for the active filter, searchable and
/// sortable. The toolbar carries Filter, an overflow (Sort/Export), and the "+"
/// Add menu. Selecting a row drives the detail column (and pushes on iPhone).
struct ReceiptListView: View {
    @Binding var filter: ReceiptFilter
    @Binding var selection: Receipt?

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @Query(sort: \Receipt.createdAt, order: .reverse) private var allReceipts: [Receipt]

    @State private var searchText = ""
    @State private var sort: ReceiptSort = .dateNewest

    // Export — Mac uses a Save panel; iPhone/iPad use the Share sheet.
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
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                filterMenu
            } label: {
                Label("Filter", systemImage: filter.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }

            Menu {
                Picker("Sort By", selection: $sort) {
                    ForEach(ReceiptSort.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(option)
                    }
                }
                exportControl
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }

            AddReceiptMenu()
        }
    }

    @ViewBuilder
    private var exportControl: some View {
        #if targetEnvironment(macCatalyst)
        Button("Export…", systemImage: "square.and.arrow.up") {
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

    // MARK: Filter

    @ViewBuilder
    private var filterMenu: some View {
        if filter.isActive {
            Button("Clear Filters", systemImage: "xmark.circle") { filter = ReceiptFilter() }
        }
        Picker("Year", selection: $filter.year) {
            Text("Any Year").tag(Int?.none)
            ForEach(yearsPresent, id: \.self) { year in
                Text(verbatim: String(year)).tag(Int?.some(year))
            }
        }
        Picker("Tax Line", selection: $filter.line) {
            Text("Any Line").tag(TaxLineCode?.none)
            ForEach(linesPresent, id: \.self) { code in
                Text(code.category).tag(TaxLineCode?.some(code))
            }
        }
    }

    private var yearsPresent: [Int] {
        Set(allReceipts.map(\.year)).sorted(by: >)
    }

    private var linesPresent: [TaxLineCode] {
        TaxLineCode.allCases.filter { code in
            allReceipts.contains { $0.matchedLines.contains { $0.code == code } }
        }
    }

    private var exportFilename: String { "Shoebox - \(filter.title)" }

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
                    AddReceiptButton()
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

    // MARK: Row menu + actions

    @ViewBuilder
    private func contextMenu(for receipt: Receipt) -> some View {
        if receipt.imageData != nil {
            Button("Read Again", systemImage: "arrow.clockwise") {
                processor.reprocess(receipt, in: modelContext)
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { delete(receipt) }
    }

    private func delete(_ receipt: Receipt) {
        if selection == receipt { selection = nil }
        modelContext.delete(receipt)
        try? modelContext.save()
    }
}
