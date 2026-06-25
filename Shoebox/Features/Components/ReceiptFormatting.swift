import Foundation

/// Display formatting shared across the receipt screens.
extension Receipt {
    var vendorDisplay: String {
        switch status {
        case .processing: "Reading receipt…"
        case .failed where vendor == nil: "Couldn't read this one"
        default: vendor ?? "Untitled receipt"
        }
    }

    var amountDisplay: String? {
        guard let total else { return nil }
        return total.formatted(.currency(code: currency).precision(.fractionLength(2)))
    }

    var dateDisplay: String? {
        guard let date else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var longDateDisplay: String? {
        guard let date else { return nil }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}
