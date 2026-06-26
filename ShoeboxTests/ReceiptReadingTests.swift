import Testing
import Foundation
@testable import Shoebox

@Suite("Receipt reading + mock reader")
struct ReceiptReadingTests {
    private func input(_ fileName: String) -> ReceiptInput {
        ReceiptInput(data: Data(), mimeType: "image/jpeg", fileName: fileName)
    }

    @Test("Mock reader keys off the filename: donation → needs attention on line 34900")
    func donationBranch() async throws {
        let reading = try await MockReceiptReader(delay: .zero).read(input("donation-1.jpg"))
        #expect(reading.status == .needsAttention)
        #expect(reading.matchedLines.map(\.code) == [.donations])
        #expect(!reading.reasons.isEmpty)
    }

    @Test("Mock reader: daycare → acceptable child-care receipt")
    func daycareBranch() async throws {
        let reading = try await MockReceiptReader(delay: .zero).read(input("daycare.pdf"))
        #expect(reading.status == .acceptable)
        #expect(reading.matchedLines.first?.code == .childCare)
    }

    @Test("Mock reader: blurry capture throws so the receipt lands in failed")
    func blurryThrows() async {
        await #expect(throws: ReceiptReaderError.self) {
            _ = try await MockReceiptReader(delay: .zero).read(input("blurry.jpg"))
        }
    }

    @Test("Only high-confidence, known, real lines are kept; medium/low/unknown/dupes are dropped")
    func keepsOnlyHighConfidence() {
        let reading = makeReading(lines: [
            ("33099", "high"),
            ("34900", "medium"),    // dropped: not high confidence
            ("99999", "high"),      // dropped: unknown code
            ("33099", "high"),      // dropped: duplicate
        ])
        #expect(reading.matchedLines.map(\.code) == [.medical])
    }

    @Test("Falls back to Other only when no high-confidence line qualifies")
    func fallsBackToOther() {
        let reading = makeReading(lines: [("34900", "medium"), ("21400", "low")])
        #expect(reading.matchedLines.map(\.code) == [.other])
    }

    @Test("A model-returned 'other' is the fallback, never a real selection")
    func otherIsNeverAReadSelection() {
        let reading = makeReading(lines: [("other", "high")])
        #expect(reading.matchedLines.map(\.code) == [.other])
    }

    /// Build a reading with only line matches set (other fields nil).
    private func makeReading(lines: [(String, String)]) -> ReceiptReading {
        ReceiptReading(
            vendor: nil, date: nil, total: nil, currency: nil, taxAmount: nil,
            details: nil, charityRegistration: nil, providerName: nil,
            verdict: .acceptable, reasons: [],
            lines: lines.map { .init(code: $0.0, confidence: $0.1) }
        )
    }

    @Test("ISO date strings parse into a Date")
    func dateParsing() {
        let reading = ReceiptReading(
            vendor: nil, date: "2026-06-14", total: nil, currency: nil, taxAmount: nil,
            details: nil, charityRegistration: nil, providerName: nil,
            verdict: .acceptable, reasons: [], lines: []
        )
        let parsed = try? #require(reading.parsedDate)
        #expect(parsed != nil)
    }
}
