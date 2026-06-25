import Foundation
import FoundationModels

/// The production reader: Vision OCR → **Apple Intelligence** on-device language
/// model with guided generation. Nothing leaves the device.
struct FoundationModelsReceiptReader: ReceiptReader {
    func read(_ input: ReceiptInput) async throws -> ReceiptReading {
        // Fail fast if Apple Intelligence isn't usable on this device.
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw ReceiptReaderError.modelUnavailable(String(describing: reason))
        }

        let recognizedText = try await ReceiptOCR.recognizeText(from: input)

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = """
        Read the recognized text from one receipt below and return the structured result. \
        Leave any field null if it is illegible or absent. Identify every T1 line it may apply to.

        RECEIPT TEXT:
        \(recognizedText)
        """

        let response = try await session.respond(to: prompt, generating: ReceiptReading.self)
        return response.content
    }

    /// System instructions encoding the PRD §8 CRA acceptability criteria and the
    /// conservative-validation / no-amount-computation rules.
    static let instructions: String = {
        let criteria = TaxLineCode.allCases.map { code -> String in
            let meta = TaxLine.meta(for: code)
            let label = [meta.line, meta.category].compactMap { $0 }.joined(separator: " — ")
            return "- \(label): \(meta.acceptanceCriteria)"
        }.joined(separator: "\n")

        return """
        You are a careful assistant for a Canadian personal (T1) income-tax receipt organizer.
        You are given the OCR text of a single receipt. Your job is to:
        1. EXTRACT the vendor, date, total, currency, tax amount, a short description, and any
           document-type identifiers (charity registration/BN number, child-care provider name).
        2. VALIDATE whether the receipt would be acceptable to the Canada Revenue Agency (CRA) as
           support for a claim. Be CONSERVATIVE: when in doubt, choose needsAttention rather than
           asserting it is acceptable. If it is clearly not a receipt, choose notATaxReceipt.
           When the verdict is not acceptable, give specific, plain-language reasons.
        3. MATCH the receipt to one or more of the supported T1 lines below (or none), each with a
           confidence of high, medium, or low.

        Do NOT compute deductible or creditable amounts, apply thresholds, or total a claim — only
        extract, validate acceptability, and match lines.

        Supported T1 lines and their CRA acceptability criteria:
        \(criteria)
        """
    }()
}
