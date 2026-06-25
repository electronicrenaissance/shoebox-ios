import SwiftUI
import SwiftData

/// Manual correction of the AI's reading (PRD FR-AI5 / FR-R3): every extracted
/// field, the matched line(s), and an acceptability override are editable. The
/// immutable `aiBaselineJSON` is preserved so corrections can be measured.
struct ReceiptEditView: View {
    @Bindable var receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var hasDate: Bool

    init(receipt: Receipt) {
        self.receipt = receipt
        _hasDate = State(initialValue: receipt.date != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledTextField(label: "Payee", text: vendorBinding)
                    Toggle("Has a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    }
                    LabeledNumberField(label: "Total", value: $receipt.total)
                    LabeledTextField(label: "Currency", text: $receipt.currency)
                    LabeledNumberField(label: "GST/HST", value: $receipt.taxAmount)
                    LabeledTextField(label: "Description", text: detailsBinding)
                }

                Section("Identifiers") {
                    LabeledTextField(label: "Charity registration #", text: charityBinding)
                    LabeledTextField(label: "Provider name", text: providerBinding)
                }

                Section("Tax lines") {
                    ForEach(TaxLineCode.allCases, id: \.self) { code in
                        Toggle(isOn: lineBinding(for: code)) {
                            let meta = TaxLine.meta(for: code)
                            VStack(alignment: .leading) {
                                Text(meta.category)
                                if let line = meta.line {
                                    Text("Line \(line)").font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Mark CRA-ready", isOn: $receipt.acceptabilityOverride)
                } footer: {
                    Text("Override the automatic check and treat this receipt as acceptable.")
                }
            }
            .navigationTitle("Edit receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { modelContext.rollback(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Save

    private func save() {
        if !hasDate { receipt.date = nil }
        if receipt.acceptabilityOverride {
            receipt.status = .acceptable
            receipt.validationReasons = []
        }
        receipt.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    // MARK: Bindings (optional string ↔ non-optional field helpers)

    private var vendorBinding: Binding<String> { optionalText(\.vendor) }
    private var detailsBinding: Binding<String> { optionalText(\.details) }
    private var charityBinding: Binding<String> { optionalText(\.charityRegistration) }
    private var providerBinding: Binding<String> { optionalText(\.providerName) }

    private var dateBinding: Binding<Date> {
        Binding(get: { receipt.date ?? .now }, set: { receipt.date = $0 })
    }

    private func optionalText(_ keyPath: ReferenceWritableKeyPath<Receipt, String?>) -> Binding<String> {
        Binding(
            get: { receipt[keyPath: keyPath] ?? "" },
            set: { receipt[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func lineBinding(for code: TaxLineCode) -> Binding<Bool> {
        Binding(
            get: { receipt.matchedLines.contains { $0.code == code } },
            set: { isOn in
                if isOn {
                    if !receipt.matchedLines.contains(where: { $0.code == code }) {
                        receipt.matchedLines.append(TaxLineMatch(code: code, confidence: .medium))
                    }
                } else {
                    receipt.matchedLines.removeAll { $0.code == code }
                }
            }
        )
    }
}

// MARK: - Field rows

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            TextField(label, text: $text).multilineTextAlignment(.trailing)
        }
    }
}

private struct LabeledNumberField: View {
    let label: String
    @Binding var value: Double?
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            TextField(label, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }
}

#Preview {
    ReceiptEditView(receipt: SampleData.makeReceipts()[1])
        .modelContainer(ShoeboxStore.previewContainer())
}
