import Foundation

extension TaxLineCode {
    /// SF Symbol representing the line, used in the sidebar and chips.
    var systemImage: String {
        switch self {
        case .medical: "cross.case.fill"
        case .donations: "heart.fill"
        case .childCare: "figure.and.child.holdinghands"
        case .digitalNews: "newspaper.fill"
        case .moving: "shippingbox.fill"
        case .homeAccessibility: "house.fill"
        case .politicalContributions: "building.columns.fill"
        case .other: "tag.fill"
        }
    }

    var category: String { TaxLine.meta(for: self).category }

    /// "Line 34900 · Schedule 9" style subtitle, or just the category for `other`.
    var lineSubtitle: String {
        let meta = TaxLine.meta(for: self)
        guard let line = meta.line else { return meta.category }
        if let form = meta.form { return "Line \(line) · \(form)" }
        return "Line \(line)"
    }
}
