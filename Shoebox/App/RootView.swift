import SwiftUI
import SwiftData

/// The app's adaptive shell. A three-column `NavigationSplitView`:
/// sidebar (filters) → list → detail. On iPad/Mac this is a true three-pane
/// layout; on iPhone it collapses to a push navigation stack, starting on the
/// list with the filters one step back.
struct RootView: View {
    @State private var filter: ReceiptFilter? = .all
    @State private var selection: Receipt?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredColumn: NavigationSplitViewColumn = .content

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            SidebarView(selection: $filter)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            ReceiptListView(filter: filter ?? .all, selection: $selection)
                .navigationSplitViewColumnWidth(min: 340, ideal: 400)
        } detail: {
            DetailColumn(receipt: selection)
        }
        .navigationSplitViewStyle(.balanced)
        // Clearing selection when the filter changes avoids showing a receipt that
        // is no longer in the visible list.
        .onChange(of: filter) { selection = nil }
    }
}

/// Detail pane content — the selected receipt, or a placeholder on iPad/Mac when
/// nothing is selected.
private struct DetailColumn: View {
    let receipt: Receipt?

    var body: some View {
        if let receipt {
            ReceiptDetailView(receipt: receipt)
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
