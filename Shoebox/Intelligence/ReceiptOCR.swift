import Foundation
import Vision
import UIKit
import PDFKit

/// On-device text recognition. The Apple Intelligence language model is
/// text-only, so we get the receipt's text first and feed it to the model.
///
/// For PDFs we prefer the document's **embedded text layer** (clean, exact) when
/// it has one, and fall back to rasterizing + Vision OCR for scanned PDFs and all
/// images.
enum ReceiptOCR {
    /// Recognize the receipt's text, newline-separated in reading order.
    static func recognizeText(from input: ReceiptInput) async throws -> String {
        let log = IntelligenceLog.logger
        log.info("OCR start: \(input.fileName, privacy: .public) [\(input.mimeType, privacy: .public), \(input.data.count) bytes]")

        // Prefer a PDF's embedded text layer over OCR'ing a rasterized page.
        if input.mimeType == "application/pdf", let embedded = embeddedPDFText(input.data) {
            log.info("Text source: PDF embedded layer — \(embedded.count) chars")
            log.debug("Recognized text (PDF embedded layer):\n\(embedded, privacy: .public)")
            return embedded
        }

        let started = Date()
        let cgImage = try rasterize(input)

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let observations = try await request.perform(on: cgImage)
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)

        log.info("Text source: Vision OCR — \(observations.count) lines, \(text.count) chars in \(elapsedMs)ms")
        log.debug("Recognized text (Vision OCR):\n\(text, privacy: .public)")

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log.error("OCR found no readable text in \(input.fileName, privacy: .public)")
            throw ReceiptReaderError.noTextFound
        }
        return text
    }

    /// The PDF's embedded text layer, if it carries one with real content.
    /// Returns `nil` for scanned/image-only PDFs so the caller falls back to OCR.
    static func embeddedPDFText(_ data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        let text = (document.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Require some substance — a near-empty layer means it's effectively a scan.
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
            let scale: CGFloat = 2 // upscale for sharper OCR
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
