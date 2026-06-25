import Foundation

/// Federal **T1** personal income-tax lines the MVP can match a receipt to
/// (PRD 001 §8). `other` is the uncategorized fallback. Extensible — add a case
/// plus a `TaxLine` entry and the rest of the app picks it up.
enum TaxLineCode: String, CaseIterable, Codable, Sendable {
    case medical = "33099"
    case donations = "34900"
    case childCare = "21400"
    case digitalNews = "31350"
    case moving = "21900"
    case homeAccessibility = "31285"
    case politicalContributions = "40900"
    case other
}

/// Display metadata + the CRA acceptability criteria the on-device model checks
/// when matching a receipt to this line.
struct TaxLine: Identifiable, Sendable {
    let code: TaxLineCode
    /// Display label, e.g. "Medical expenses".
    let category: String
    /// Related CRA form/schedule, or `nil`.
    let form: String?
    /// The line number as printed on the return, or `nil` for `other`.
    let line: String?
    /// Short description of what the CRA requires for this line to be acceptable,
    /// fed to the on-device model as part of its instructions.
    let acceptanceCriteria: String

    var id: TaxLineCode { code }

    static let all: [TaxLineCode: TaxLine] = [
        .medical: TaxLine(
            code: .medical,
            category: "Medical expenses",
            form: "Schedule 1 (METC)",
            line: "33099 / 33199",
            acceptanceCriteria: "Eligible expense; shows payee/provider name, patient, date, amount, and a description of the service or item."
        ),
        .donations: TaxLine(
            code: .donations,
            category: "Donations & gifts",
            form: "Schedule 9",
            line: "34900",
            acceptanceCriteria: "Must be an OFFICIAL donation receipt from a registered charity: charity name + registration (BN) number, date, eligible amount, the words \"official receipt for income tax purposes\", and the CRA website. A plain sales slip is NOT acceptable."
        ),
        .childCare: TaxLine(
            code: .childCare,
            category: "Child care expenses",
            form: "T778",
            line: "21400",
            acceptanceCriteria: "Provider name, amount, and date; the provider's SIN if the provider is an individual."
        ),
        .digitalNews: TaxLine(
            code: .digitalNews,
            category: "Digital news subscription",
            form: nil,
            line: "31350",
            acceptanceCriteria: "Subscription to a Qualified Canadian Journalism Organization (QCJO); shows vendor and amount."
        ),
        .moving: TaxLine(
            code: .moving,
            category: "Moving expenses",
            form: "T1-M",
            line: "21900",
            acceptanceCriteria: "Standard receipt fields plus an expense type tied to an eligible move (movers, transport, temporary lodging)."
        ),
        .homeAccessibility: TaxLine(
            code: .homeAccessibility,
            category: "Home accessibility expenses",
            form: "Schedule 12",
            line: "31285",
            acceptanceCriteria: "Standard receipt for renovation work; an eligible dwelling / qualifying individual; description of the work."
        ),
        .politicalContributions: TaxLine(
            code: .politicalContributions,
            category: "Federal political contributions",
            form: nil,
            line: "40900",
            acceptanceCriteria: "Official contribution receipt from a registered federal party/candidate, with the registered entity and amount."
        ),
        .other: TaxLine(
            code: .other,
            category: "Other / Uncategorized",
            form: nil,
            line: nil,
            acceptanceCriteria: "Anything the system can't confidently place on a supported line."
        ),
    ]

    static func meta(for code: TaxLineCode) -> TaxLine { all[code] ?? all[.other]! }
}

/// AI confidence for a single line match (PRD FR-AI4).
enum Confidence: String, Codable, Sendable {
    case high, medium, low
}

/// A tax line the receipt may apply to, with the model's confidence.
struct TaxLineMatch: Codable, Hashable, Sendable {
    var code: TaxLineCode
    var confidence: Confidence

    var meta: TaxLine { TaxLine.meta(for: code) }
}
