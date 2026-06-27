import SwiftUI
import SwiftData

/// Manual correction of the model's reading (PRD FR-AI5 / FR-R3): every extracted
/// field, the matched line(s), and an acceptability override. A native grouped
/// `Form` presented as a sheet. The immutable `aiBaselineJSON` is preserved.
///
/// If the receipt is still being read (e.g. opened right after a single import),
/// the form shows a "Reading…" progress banner with redacted, non-editable fields
/// until the on-device model finishes, then reveals the populated form.
struct ReceiptEditView: View {
    @Bindable var receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var isReading: Bool { receipt.status == .processing }

    var body: some View {
        NavigationStack {
            Form {
                if isReading { readingBanner }

                Group {
                    Section("Details") {
                        TextField("Payee", text: optionalText(\.vendor))
                        DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                        LabeledContent("Total") {
                            TextField("Amount", value: $receipt.total, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if !targetEnvironment(macCatalyst)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        Picker("Currency", selection: $receipt.currency) {
                            ForEach(CurrencyOption.options(including: receipt.currency)) { option in
                                Text(option.label).tag(option.code)
                            }
                        }
                        LabeledContent("GST/HST") {
                            TextField("Tax", value: $receipt.taxAmount, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if !targetEnvironment(macCatalyst)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        TextField("Description", text: optionalText(\.details), axis: .vertical)
                            .lineLimit(1...4)
                    }

                    Section("Identifiers") {
                        TextField("Charity registration №", text: optionalText(\.charityRegistration))
                        TextField("Provider name", text: optionalText(\.providerName))
                    }

                    Section("Tax Lines") {
                        ForEach(TaxLineCode.allCases, id: \.self) { code in
                            Toggle(isOn: lineBinding(for: code)) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(code.category)
                                        Text(code.lineSubtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: code.systemImage)
                                }
                            }
                        }
                    }

                    Section {
                        Toggle("Mark CRA-ready", isOn: isCRAReadyBinding)
                    } footer: {
                        Text("Treat this receipt as acceptable to the CRA.")
                    }
                }
                .disabled(isReading)
                .redacted(reason: isReading ? .placeholder : [])
            }
            .formStyle(.grouped)
            .animation(.default, value: isReading)
            .navigationTitle("Edit Receipt")
            #if !targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { modelContext.rollback(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(isReading)
                }
            }
        }
    }

    private var readingBanner: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading your receipt…")
                        .font(.subheadline.weight(.semibold))
                    Text("Apple Intelligence is filling in the details on your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Save

    private func save() {
        // Date is required; guard against any legacy receipt that lacks one.
        if receipt.date == nil { receipt.date = .now }
        receipt.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    // MARK: Bindings

    private var dateBinding: Binding<Date> {
        Binding(get: { receipt.date ?? .now }, set: { receipt.date = $0 })
    }

    /// Toggling "Mark CRA-ready" sets the status directly: on → acceptable (and
    /// clears the validation reasons), off → needs attention.
    private var isCRAReadyBinding: Binding<Bool> {
        Binding(
            get: { receipt.status == .acceptable },
            set: { isOn in
                receipt.status = isOn ? .acceptable : .needsAttention
                if isOn { receipt.validationReasons = [] }
            }
        )
    }

    private func optionalText(_ keyPath: ReferenceWritableKeyPath<Receipt, String?>) -> Binding<String> {
        Binding(
            get: { receipt[keyPath: keyPath].sanitized ?? "" },
            set: { receipt[keyPath: keyPath] = $0.sanitized }
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

#Preview {
    ReceiptEditView(receipt: SampleData.makeReceipts()[1])
        .modelContainer(ShoeboxStore.previewContainer())
}
