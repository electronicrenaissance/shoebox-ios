import Foundation

/// A selectable currency for the editor: ISO code, localized name, and a flag.
/// Ordered with the most common first (CAD, USD, EUR, GBP), then every other
/// currency alphabetically by code.
struct CurrencyOption: Identifiable, Hashable, Sendable {
    let code: String   // e.g. "CAD"
    let name: String   // e.g. "Canadian Dollar"
    let flag: String   // e.g. "🇨🇦"

    var id: String { code }

    /// "🇨🇦 CAD - Canadian Dollar"
    var label: String { "\(flag) \(code) - \(name)" }

    /// Currencies shown at the top of the list, in this order.
    static let priorityCodes = ["CAD", "USD", "EUR", "GBP"]

    /// All common ISO currencies: the priority ones first, then the rest sorted
    /// alphabetically by code.
    static let all: [CurrencyOption] = {
        let priority = priorityCodes.compactMap(make)
        let prioritySet = Set(priorityCodes)
        let rest = Locale.commonISOCurrencyCodes
            .filter { !prioritySet.contains($0) }
            .compactMap(make)
            .sorted { $0.code < $1.code }
        return priority + rest
    }()

    /// `all`, guaranteeing the given code is present (so the picker can always
    /// reflect an unusual value the model may have returned).
    static func options(including code: String) -> [CurrencyOption] {
        guard !code.isEmpty, !all.contains(where: { $0.code == code }) else { return all }
        return (make(code).map { [$0] } ?? []) + all
    }

    /// Build an option for a code, or `nil` if it has no localized name.
    static func make(_ code: String) -> CurrencyOption? {
        guard let name = Locale.current.localizedString(forCurrencyCode: code) else { return nil }
        return CurrencyOption(code: code, name: name, flag: flag(for: code))
    }

    /// Flag emoji derived from the currency code's country prefix (e.g. "CAD" →
    /// "CA" → 🇨🇦). EUR maps to the EU flag; codes without a real ISO region
    /// (e.g. the "X…" supranational/metal codes) fall back to a generic symbol.
    static func flag(for code: String) -> String {
        if code == "EUR" { return "🇪🇺" }
        let region = String(code.prefix(2)).uppercased()
        guard Locale.Region(region).isISORegion else { return "💱" }

        let base: UInt32 = 0x1F1E6 - 0x41 // regional-indicator 'A' minus ASCII 'A'
        var flag = ""
        for scalar in region.unicodeScalars {
            guard let indicator = UnicodeScalar(base + scalar.value) else { return "💱" }
            flag.unicodeScalars.append(indicator)
        }
        return flag.isEmpty ? "💱" : flag
    }
}
