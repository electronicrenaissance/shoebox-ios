import Foundation
import FoundationModels

/// The production reader: Vision OCR → **Apple Intelligence** on-device language
/// model with guided generation. Nothing leaves the device.
struct FoundationModelsReceiptReader: ReceiptReader {
    func read(_ input: ReceiptInput) async throws -> ReceiptReading {
        let log = IntelligenceLog.logger

        // Fail fast if Apple Intelligence isn't usable on this device.
        switch SystemLanguageModel.default.availability {
        case .available:
            log.info("Apple Intelligence: available")
        case .unavailable(let reason):
            log.error("Apple Intelligence unavailable: \(String(describing: reason), privacy: .public)")
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
        log.debug("Model prompt:\n\(prompt, privacy: .public)")

        let started = Date()
        do {
            // Low temperature keeps extraction and the verdict deterministic — the
            // small on-device model is otherwise flaky run-to-run (it would
            // occasionally return empty fields or contradict itself).
            let response = try await session.respond(
                to: prompt,
                generating: ReceiptReading.self,
                options: GenerationOptions(temperature: 0.1)
            )
            let reading = response.content
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)

            let lines = reading.matchedLines
                .map { "\($0.code.rawValue):\($0.confidence.rawValue)" }
                .joined(separator: ",")
            log.info("""
            Model done in \(elapsedMs)ms → verdict=\(String(describing: reading.verdict), privacy: .public) \
            lines=[\(lines, privacy: .public)] vendor=\(reading.vendor ?? "nil", privacy: .public) \
            total=\(reading.total ?? -1) date=\(reading.date ?? "nil", privacy: .public) \
            BN=\(reading.charityRegistration ?? "nil", privacy: .public)
            """)
            for reason in reading.reasons {
                log.info("  reason: \(reason, privacy: .public)")
            }
            return reading
        } catch {
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            log.error("Model generation failed after \(elapsedMs)ms: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// System instructions encoding the PRD §8 CRA acceptability criteria and the
    /// validation / no-amount-computation rules. The criteria list is built from
    /// the `TaxLine` taxonomy so adding a line there updates the prompt too.
    ///
    /// The verdict RULE is deliberately explicit: the small on-device model would
    /// otherwise list a receipt's required elements as present yet still return
    /// `needsAttention` (over-applying "when in doubt, flag it"). It also tends to
    /// over-match lines, so we tell it to match only what clearly applies.
    static let instructions: String = {
        let criteria = TaxLineCode.allCases.map { code -> String in
            let meta = TaxLine.meta(for: code)
            let label = [meta.line, meta.category].compactMap { $0 }.joined(separator: " ")
            return "- \(label): \(meta.acceptanceCriteria)"
        }.joined(separator: "\n")

        return """
        You are a careful assistant for a Canadian personal (T1) income-tax receipt organizer.
        Given the text of ONE receipt, do three things:

        1. EXTRACT the vendor, date (ISO yyyy-MM-dd), total, currency, tax amount, a short
           description, and any identifiers (charity registration/BN number, child-care provider
           name). Use null for anything that is absent or illegible.

        2. VALIDATE acceptability to the CRA, choosing exactly one verdict:
           - acceptable: the receipt clearly contains ALL required elements for at least one matched line.
           - needsAttention: it is a receipt, but one or more required elements are missing or unclear.
           - notATaxReceipt: it is not a receipt, or not for an eligible expense.
           RULE: If all required elements for a line are present, you MUST choose acceptable and leave
           `reasons` empty. Do NOT downgrade a complete receipt or invent caveats. Only choose
           needsAttention when a specific required element is missing — then name exactly what is missing.

        3. MATCH only the line(s) that clearly apply, each with a confidence of high, medium, or low.
           Use HIGH confidence only when the receipt clearly meets that line's required elements;
           otherwise use medium or low. Returning no line is fine — do NOT force a match, and never
           add a line that does not fit the document (for example, never tag a donation receipt as
           child care).

        Do NOT compute deductible or creditable amounts, apply thresholds, or total a claim.

        Supported T1 lines and their required elements:
        \(criteria)
        """
    }()
}
