import SwiftUI

/// Visual tones for pills/badges, ported from the web design system.
enum BadgeTone {
    case line, ok, warn, fail, muted

    var foreground: Color {
        switch self {
        case .line: Theme.brandDark
        case .ok: Color(hex: 0x15803D)
        case .warn: Color(hex: 0xB45309)
        case .fail: Color(hex: 0xDC2626)
        case .muted: Theme.muted
        }
    }

    var background: Color {
        switch self {
        case .line: Theme.brandLight
        case .ok: Color(hex: 0xF0FDF4)
        case .warn: Color(hex: 0xFFFBEB)
        case .fail: Color(hex: 0xFEF2F2)
        case .muted: Theme.paper
        }
    }
}

/// A small rounded pill with an optional SF Symbol, matching the design badges.
struct Badge: View {
    var tone: BadgeTone = .muted
    var systemImage: String?
    var text: String

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            }
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(tone.foreground)
        .background(tone.background, in: Capsule())
        .overlay(Capsule().strokeBorder(tone.foreground.opacity(0.15)))
    }
}

/// Status pill for a receipt's lifecycle/CRA verdict.
struct StatusBadge: View {
    let status: ReceiptStatus

    var body: some View {
        Badge(tone: status.tone, systemImage: status.systemImage, text: status.label)
    }
}

/// Tax-line chip, e.g. "Medical · 33099".
struct TaxLineBadge: View {
    let match: TaxLineMatch

    var body: some View {
        let meta = match.meta
        let suffix = meta.line.map { " · \($0)" } ?? ""
        return Badge(tone: .line, text: "\(meta.category)\(suffix)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StatusBadge(status: .acceptable)
        StatusBadge(status: .needsAttention)
        StatusBadge(status: .processing)
        StatusBadge(status: .failed)
        TaxLineBadge(match: .init(code: .medical, confidence: .high))
    }
    .padding()
    .background(Theme.paper)
}
