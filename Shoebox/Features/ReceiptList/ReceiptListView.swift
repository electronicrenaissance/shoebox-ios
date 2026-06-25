import SwiftUI
import SwiftData

/// The app's home: the user's receipts, newest first, with an add affordance.
/// This is the post-launch root — no sign-in stands in front of it.
struct ReceiptListView: View {
    @Query(sort: \Receipt.createdAt, order: .reverse)
    private var receipts: [Receipt]

    @Environment(\.modelContext) private var modelContext
    @Environment(ReceiptProcessor.self) private var processor

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    EmptyStateView(onAdd: { showingAdd = true })
                } else {
                    list
                }
            }
            .background(Theme.paper)
            .navigationTitle("Shoebox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add receipt")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddReceiptSheet { input in
                    processor.ingest(input, into: modelContext)
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(receipts) { receipt in
                    NavigationLink(value: receipt) {
                        ReceiptRow(receipt: receipt)
                    }
                    .listRowBackground(Theme.paper)
                }
                .onDelete(perform: delete)
            } header: {
                summaryHeader
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Receipt.self) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
    }

    private var summaryHeader: some View {
        let needsAttention = receipts.filter { $0.status == .needsAttention }.count
        return HStack {
            Text("^[\(receipts.count) receipt](inflect: true)")
            Spacer()
            if needsAttention > 0 {
                Text("\(needsAttention) need attention")
                    .foregroundStyle(BadgeTone.warn.foreground)
                    .fontWeight(.medium)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.muted)
        .textCase(nil)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(receipts[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    ReceiptListView()
        .environment(ReceiptProcessor(reader: MockReceiptReader()))
        .modelContainer(ShoeboxStore.previewContainer())
}
