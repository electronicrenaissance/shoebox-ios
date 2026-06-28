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

    @Test("A high-confidence real line is filed under that line")
    func highConfidenceLineIsFiled() {
        let reading = makeReading(line: .medical, confidence: .high)
        #expect(reading.matchedLines.map(\.code) == [.medical])
    }

    @Test("A non-high-confidence line falls back to Other")
    func mediumConfidenceFallsBackToOther() {
        #expect(makeReading(line: .donations, confidence: .medium).matchedLines.map(\.code) == [.other])
        #expect(makeReading(line: nil, confidence: .low).matchedLines.map(\.code) == [.other])
    }

    @Test("A 'other' line is the fallback, never a real selection")
    func otherIsNeverAReadSelection() {
        #expect(makeReading(line: .other, confidence: .high).matchedLines.map(\.code) == [.other])
    }

    @Test("Sanitizing turns literal null / blank placeholders into nil")
    func sanitizing() {
        #expect("null".sanitized == nil)
        #expect("  NULL ".sanitized == nil)
        #expect("N/A".sanitized == nil)
        #expect("".sanitized == nil)
        #expect("-".sanitized == nil)
        #expect("Shoppers Drug Mart".sanitized == "Shoppers Drug Mart")
        #expect(("null" as String?).sanitized == nil)
        #expect((nil as String?).sanitized == nil)
        #expect((" Hope Mission " as String?).sanitized == "Hope Mission")
    }

    @Test("A receipt always has a date; a read without one keeps the existing date")
    func dateIsAlwaysPresent() {
        let receipt = Receipt(fileName: "x.jpg", mimeType: "image/jpeg", imageData: nil)
        #expect(receipt.date != nil)
        let original = receipt.date
        receipt.apply(makeReading(line: nil, confidence: .low))  // reading carries no date
        #expect(receipt.date == original)
    }

    @Test("ISO date strings parse into a Date")
    func dateParsing() {
        let reading = makeReading(line: nil, confidence: .low, date: "2026-06-14")
        let parsed = try? #require(reading.parsedDate)
        #expect(parsed != nil)
    }

    /// Build a minimal reading with just the line classification (other fields nil).
    private func makeReading(line: TaxLineCode?, confidence: Confidence, date: String? = nil) -> ReceiptReading {
        ReceiptReading(
            vendor: nil, date: date, total: nil, currency: nil, taxAmount: nil,
            details: nil, charityRegistration: nil, providerName: nil,
            status: .acceptable, reasons: [], line: line, lineConfidence: confidence
        )
    }
}
