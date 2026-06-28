import Foundation
import FoundationModels

/// The production reader: Vision document OCR → **Apple Intelligence** on-device
/// model. Nothing leaves the device.
///
/// Two design points learned the hard way:
/// - The read is **two sequential calls** (extract, then classify). The small model
///   is reliable on a short, single-purpose prompt but drops fields (or tags every
///   line) when asked to extract + validate + match at once.
/// - We use **permissive content guardrails** and **terse** classification criteria.
///   The default guardrail / verbose CRA criteria make the model's content
///   classifier false-positive ("may contain sensitive content") and *refuse* on
///   ordinary receipts that mention health, children, etc. Refusals are also caught
///   and degraded so they can never fail a receipt.
struct FoundationModelsReceiptReader: ReceiptReader {
    /// Permissive guardrails — the mode Apple provides for transforming the user's
    /// own content on-device (the default over-refuses on personal documents).
    private let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    func read(_ input: ReceiptInput) async throws -> ReceiptReading {
        let log = IntelligenceLog.logger

        switch model.availability {
        case .available:
            log.info("Apple Intelligence: available")
        case .unavailable(let reason):
            log.error("Apple Intelligence unavailable: \(String(describing: reason), privacy: .public)")
            throw ReceiptReaderError.modelUnavailable(String(describing: reason))
        }

        let text = try await ReceiptOCR.recognizeText(from: input)
        let prompt = "RECEIPT TEXT:\n\(text)"

        // Call 1 — extraction (deterministic). Degrade to empty on a refusal.
        let extractStart = Date()
        let extraction: ReceiptExtraction
        do {
            extraction = try await generate(Self.extractInstructions, prompt, temperature: 0)
        } catch let error as LanguageModelSession.GenerationError where error.isRefusal {
            log.error("Extraction refused — degrading to empty fields")
            extraction = .empty
        }
        // Prefer the BN read from the PDF text layer; otherwise accept the model's
        // value only if it's actually a charity-number format (not a plan/member ID).
        let charityRegistration = ReceiptOCR.embeddedCharityNumber(from: input)
            ?? extraction.charityRegistration.flatMap(ReceiptOCR.validCharityNumber)
        let extractMs = Int(Date().timeIntervalSince(extractStart) * 1000)

        // Call 2 — classification (single best line + verdict). Degrade to
        // needs-attention/other on a refusal so the receipt is never lost.
        let classifyStart = Date()
        let classification: ReceiptClassification
        do {
            classification = try await generate(Self.classifyInstructions, prompt, temperature: 0.1)
        } catch let error as LanguageModelSession.GenerationError where error.isRefusal {
            log.error("Classification refused — defaulting to needs-attention / other")
            classification = .refused
        }
        let classifyMs = Int(Date().timeIntervalSince(classifyStart) * 1000)

        let reading = ReceiptReading(
            vendor: extraction.vendor,
            date: extraction.date,
            total: extraction.total,
            currency: extraction.currency,
            taxAmount: extraction.taxAmount,
            details: extraction.details,
            charityRegistration: charityRegistration,
            providerName: extraction.providerName,
            status: classification.verdict.status,
            reasons: classification.reasons,
            line: TaxLineCode(rawValue: classification.line.lowercased()),
            lineConfidence: Confidence(rawValue: classification.confidence.lowercased()) ?? .low
        )

        log.info("""
        Read done (extract \(extractMs)ms + classify \(classifyMs)ms) → \
        status=\(reading.status.rawValue, privacy: .public) line=\(classification.line, privacy: .public):\(classification.confidence, privacy: .public) \
        vendor=\(reading.vendor ?? "nil", privacy: .public) total=\(reading.total ?? -1) \
        date=\(reading.date ?? "nil", privacy: .public) BN=\(reading.charityRegistration ?? "nil", privacy: .public)
        """)
        for reason in reading.reasons {
            log.info("  reason: \(reason, privacy: .public)")
        }
        return reading
    }

    private func generate<Content: Generable>(
        _ instructions: String,
        _ prompt: String,
        temperature: Double
    ) async throws -> Content {
        let session = LanguageModelSession(model: model, instructions: instructions)
        return try await session.respond(
            to: prompt,
            generating: Content.self,
            options: GenerationOptions(temperature: temperature)
        ).content
    }

    // MARK: Instructions

    static let extractInstructions = """
    Extract the fields from the recognized text of ONE Canadian receipt. Use the exact values shown in
    the text; use null ONLY when a value is truly absent. Never invent a vendor that is not in the text.
    - vendor: the business or charity name
    - date: the issue/transaction date as yyyy-MM-dd
    - total, currency (default CAD), and GST/HST tax amount if shown
    - a short description of what was purchased or donated
    - charity registration number (format 9 digits + RR + 4 digits; null if no such number — never a phone number)
    - child-care provider name
    """

    /// Frames the choice as "paid for a service/product vs. gave a gift" — that
    /// distinction is what reliably separates medical/child-care receipts from
    /// donations (a charity can issue all three). Kept descriptive but not as
    /// verbose as the full CRA criteria, which make the model's content classifier
    /// refuse.
    static let classifyInstructions = """
    Pick the SINGLE best Canadian personal (T1) income-tax line this receipt is FOR, then a CRA verdict.
    Decide by WHAT the person received and paid for:
    - They PAID for a service or product they received → use the line for that service/product:
      * health care or products (doctor, dentist, therapist; therapy such as physio/OT/speech/ABA; prescription;
        medical device/equipment; treatment) → 33099 Medical expenses.
      * child care (daycare, nursery, nanny, day camp, before/after-school care) → 21400 Child care expenses.
      IMPORTANT: a receipt for a service or product is NEVER a donation, even when the provider is a registered
      charity or non-profit and the receipt shows a registration/BN number or the words "for income tax purposes".
    - They GAVE money as a gift/donation to a registered charity and received nothing in return (the receipt thanks
      you for a donation/gift, says "official receipt for income tax purposes", and shows a charity BN) → 34900 Donations & gifts.
    - Otherwise: 31350 Digital news subscription; 21900 Moving expenses; 31285 Home accessibility expenses;
      40900 Federal political contributions; other.
    Verdict: acceptable if it is a complete receipt for the chosen line (leave reasons empty); needsAttention if a
    required element is missing or unclear (name what is missing); notATaxReceipt if it is not a receipt.
    """
}

extension LanguageModelSession.GenerationError {
    /// The model declined to generate (its content classifier flagged the request).
    var isRefusal: Bool {
        if case .refusal = self { return true }
        return false
    }
}
