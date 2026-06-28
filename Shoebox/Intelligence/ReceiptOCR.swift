import Foundation
import Vision
import UIKit
import PDFKit
import CoreImage

/// On-device text recognition. The Apple Intelligence language model is text-only,
/// so we recognize the receipt's text first and feed it to the model.
///
/// We **OCR the rendered page** (Vision `RecognizeDocumentsRequest`, a structured
/// reading-order transcript) rather than a PDF's embedded text layer, which is
/// often scrambled and makes the model hallucinate. The page is **tiled and
/// upscaled** before OCR: Vision downsamples large images, dropping the resolution
/// small text (amounts, IDs) needs — tiling keeps each region full-size. The
/// embedded layer is used only as a fallback when OCR finds nothing, and as the
/// source for the charity registration number (tiny text OCR can't read).
enum ReceiptOCR {
    /// Recognize the receipt's text in reading order.
    static func recognizeText(from input: ReceiptInput) async throws -> String {
        let log = IntelligenceLog.logger
        log.info("OCR start: \(input.fileName, privacy: .public) [\(input.mimeType, privacy: .public), \(input.data.count) bytes]")

        let started = Date()
        let tiles = ocrTiles(try rasterize(input))
        var transcript = ""
        for tile in tiles {
            let observations = try await RecognizeDocumentsRequest().perform(on: tile)
            if let text = observations.first?.document.text.transcript, !text.isEmpty {
                transcript += transcript.isEmpty ? text : "\n" + text
            }
        }
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)

        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Vector-only PDFs may render blank; fall back to the embedded layer.
            if input.mimeType == "application/pdf", let embedded = embeddedPDFText(input.data) {
                log.info("Text source: PDF embedded layer (OCR empty) — \(embedded.count) chars")
                log.debug("Recognized text (PDF embedded layer):\n\(embedded, privacy: .public)")
                return embedded
            }
            log.error("OCR found no readable text in \(input.fileName, privacy: .public)")
            throw ReceiptReaderError.noTextFound
        }

        log.info("Text source: Vision document OCR — \(tiles.count) tile(s), \(transcript.count) chars in \(elapsedMs)ms")
        log.debug("Recognized text (Vision document OCR):\n\(transcript, privacy: .public)")
        return transcript
    }

    // MARK: Tiling + upscaling

    private static let ciContext = CIContext()

    /// Split a tall page into overlapping vertical tiles and upscale each so small
    /// text OCRs at full resolution (Vision downsamples large images). A short page
    /// becomes a single upscaled tile.
    private static func ocrTiles(_ image: CGImage) -> [CGImage] {
        let targetTileHeight = 1600
        let scale: CGFloat = 2

        guard image.height > targetTileHeight else { return [upscaled(image, scale)] }

        let count = Int((Double(image.height) / Double(targetTileHeight)).rounded(.up))
        let tileHeight = image.height / count
        let overlap = tileHeight / 6 // so a receipt straddling a seam still reads
        return (0..<count).compactMap { index in
            let y = max(0, index * tileHeight - overlap)
            let height = min(image.height - y, tileHeight + 2 * overlap)
            guard let crop = image.cropping(to: CGRect(x: 0, y: y, width: image.width, height: height)) else { return nil }
            return upscaled(crop, scale)
        }
    }

    private static func upscaled(_ image: CGImage, _ scale: CGFloat) -> CGImage {
        guard scale != 1 else { return image }
        let scaled = CIImage(cgImage: image)
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale])
        return ciContext.createCGImage(scaled, from: scaled.extent) ?? image
    }

    // MARK: Charity registration number (a standardized identifier)
    //
    // We pattern-match exactly ONE field by format, deliberately: the CRA charity
    // registration / business number is a rigid, unambiguous identifier that OCR
    // often can't read (tiny text) yet is acceptability-critical for donations.
    // This is a fenced-off exception — every free-form field (vendor, amounts,
    // dates, descriptions) goes through the model, never a regex. Only another
    // genuinely rigid standardized identifier would qualify for the same treatment.

    /// CRA charity registration / business number, e.g. `123456789 RR0001`.
    private static let charityNumberPattern = #"\d[\d ]{6,12}RR\s?\d{4}"#

    /// The registered-charity number read from a PDF's embedded text layer — often
    /// tiny text OCR can't read, but the layer has it cleanly. `nil` for images or
    /// when no such number is present.
    static func embeddedCharityNumber(from input: ReceiptInput) -> String? {
        guard input.mimeType == "application/pdf",
              let document = PDFDocument(data: input.data),
              let text = document.string,
              let range = text.range(of: charityNumberPattern, options: .regularExpression)
        else { return nil }
        return normalize(String(text[range]))
    }

    /// Returns the candidate only if it's a real charity-number format (so a model
    /// guess like a plan/member ID is dropped rather than shown as a registration #).
    static func validCharityNumber(_ candidate: String) -> String? {
        guard candidate.range(of: charityNumberPattern, options: .regularExpression) != nil else { return nil }
        return normalize(candidate)
    }

    private static func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Fallback / rendering

    /// The PDF's embedded text layer, if it carries one with real content. Only a
    /// last-resort fallback now (OCR is preferred).
    static func embeddedPDFText(_ data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        let text = (document.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count >= 20 ? text : nil
    }

    /// Decode the capture to a `CGImage`, rendering the first page for a PDF.
    static func rasterize(_ input: ReceiptInput) throws -> CGImage {
        if input.mimeType == "application/pdf" {
            guard
                let document = PDFDocument(data: input.data),
                let page = document.page(at: 0)
            else { throw ReceiptReaderError.unreadableImage }

            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2 // render sharp; tiling upscales further as needed
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let rendered = page.thumbnail(of: size, for: .mediaBox)
            guard let cgImage = rendered.cgImage else { throw ReceiptReaderError.unreadableImage }
            return cgImage
        }

        guard let image = UIImage(data: input.data), let cgImage = image.cgImage else {
            throw ReceiptReaderError.unreadableImage
        }
        return cgImage
    }
}
