import Foundation
import Vision
import UIKit
import PDFKit

/// On-device text recognition. The Apple Intelligence language model is
/// text-only, so we OCR the capture first with the Vision framework and feed the
/// recognized text into the model. PDFs are rendered to an image first.
enum ReceiptOCR {
    /// Recognize the receipt's text, newline-separated in reading order.
    static func recognizeText(from input: ReceiptInput) async throws -> String {
        let cgImage = try rasterize(input)

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let observations = try await request.perform(on: cgImage)
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptReaderError.noTextFound
        }
        return text
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
