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

    @Test("Unknown line codes fall back to .other and duplicates are removed")
    func lineMappingIsSafe() {
        let reading = ReceiptReading(
            vendor: nil, date: "2026-06-14", total: nil, currency: nil, taxAmount: nil,
            details: nil, charityRegistration: nil, providerName: nil,
            verdict: .acceptable, reasons: [],
            lines: [
                .init(code: "33099", confidence: "high"),
                .init(code: "33099", confidence: "low"),   // duplicate
                .init(code: "99999", confidence: "medium"), // unknown → other
            ]
        )
        #expect(reading.matchedLines.map(\.code) == [.medical, .other])
        #expect(reading.matchedLines.first?.confidence == .high)
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
