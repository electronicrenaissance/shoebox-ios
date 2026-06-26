import SwiftUI
import SwiftData

/// The first column: smart lists ("All", "Needs Attention") and a dynamic list of
/// the tax lines that actually have receipts, each with a live count badge.
/// Collapses behind a back button on iPhone; a persistent sidebar on iPad/Mac.
struct SidebarView: View {
    @Binding var selection: ReceiptFilter?

    @Query private var receipts: [Receipt]

    var body: some View {
        List(selection: $selection) {
            Section {
                row(.all, count: receipts.count)
                row(.needsAttention, count: receipts.count { $0.status.needsReview })
            }

            if !yearsPresent.isEmpty {
                Section("Year") {
                    ForEach(yearsPresent, id: \.self) { year in
                        row(.year(year), count: receipts.count { $0.year == year })
                    }
                }
            }

            if !linesPresent.isEmpty {
                Section("Tax Lines") {
                    ForEach(linesPresent, id: \.self) { code in
                        row(.line(code), count: receipts.count { $0.matchedLines.contains { $0.code == code } })
                    }
                }
            }
        }
        .navigationTitle("Shoebox")
    }

    private func row(_ filter: ReceiptFilter, count: Int) -> some View {
        Label(filter.title, systemImage: filter.systemImage)
            .badge(count)
            .tag(filter)
    }

    /// Years that have at least one receipt, newest first.
    private var yearsPresent: [Int] {
        Set(receipts.map(\.year)).sorted(by: >)
    }

    /// Tax lines that currently have at least one matched receipt, in taxonomy order.
    private var linesPresent: [TaxLineCode] {
        TaxLineCode.allCases.filter { code in
            receipts.contains { $0.matchedLines.contains { $0.code == code } }
        }
    }
}

private extension Array {
    /// Count of elements matching a predicate.
    func count(_ isIncluded: (Element) -> Bool) -> Int {
        reduce(0) { $0 + (isIncluded($1) ? 1 : 0) }
    }
}
