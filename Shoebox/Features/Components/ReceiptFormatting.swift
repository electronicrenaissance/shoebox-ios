import Foundation

/// Display formatting shared across the receipt screens.
extension Receipt {
    /// Calendar year of the receipt's date (falls back to when it was added).
    var year: Int {
        Calendar.current.component(.year, from: date ?? createdAt)
    }

    var vendorDisplay: String {
        switch status {
        case .processing: "Reading receipt…"
        case .failed where vendor.sanitized == nil: "Couldn't read this one"
        default: vendor.sanitized ?? "Untitled receipt"
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
