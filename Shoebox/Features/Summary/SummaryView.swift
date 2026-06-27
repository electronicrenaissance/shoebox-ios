import SwiftUI
import SwiftData
import Charts

/// The home screen: this calendar year's receipts summarized by tax line — a
/// donut of receipt totals plus tappable per-line rows that drill into Receipts.
struct SummaryView: View {
    /// Drill into the receipts for a tax line in the shown year (switches tabs).
    var onSelectLine: (TaxLineCode, Int) -> Void

    @Query private var receipts: [Receipt]
    @State private var year = Calendar.current.component(.year, from: .now)

    private var summary: YearSummary { YearSummary(receipts: receipts, year: year) }

    var body: some View {
        NavigationStack {
            Group {
                if summary.receiptCount == 0 {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Summary")
            .toolbar { yearMenu }
        }
    }

    // MARK: Content

    private var content: some View {
        List {
            if summary.total > 0 {
                Section {
                    chart
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 8))
                }
            }

            Section("By Tax Line") {
                ForEach(summary.lines) { line in
                    Button { onSelectLine(line.code, year) } label: { row(line) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var chart: some View {
        Chart(summary.lines) { line in
            SectorMark(
                angle: .value("Total", line.total),
                innerRadius: .ratio(0.64),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(line.code.tint)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 2) {
                Text(verbatim: String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.total, format: .currency(code: "CAD").precision(.fractionLength(0)))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("^[\(summary.receiptCount) receipt](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ line: TaxLineSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: line.code.systemImage)
                .foregroundStyle(line.code.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.code.category)
                Text("^[\(line.count) receipt](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(line.total, format: .currency(code: "CAD"))
                .fontWeight(.medium)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: Empty + year switcher

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing for \(String(year)) Yet", systemImage: "chart.pie")
        } description: {
            Text("Receipts you add for \(String(year)) will be summarized here by tax line.")
        } actions: {
            AddReceiptButton()
        }
    }

    @ToolbarContentBuilder
    private var yearMenu: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("Year", selection: $year) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
            } label: {
                Label(String(year), systemImage: "calendar")
            }

            AddReceiptMenu()
        }
    }

    private var availableYears: [Int] {
        var years = Set(receipts.map(\.year))
        years.insert(Calendar.current.component(.year, from: .now))
        return years.sorted(by: >)
    }
}

#Preview {
    SummaryView(onSelectLine: { _, _ in })
        .environment(ImportCoordinator())
        .modelContainer(ShoeboxStore.previewContainer())
}
