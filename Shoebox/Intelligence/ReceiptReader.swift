import Foundation

/// Input the pipeline hands to a `ReceiptReader`: the captured bytes plus the
/// MIME type (so a PDF can be rendered before OCR).
struct ReceiptInput: Sendable {
    var data: Data
    var mimeType: String
    var fileName: String
}

/// Reads a receipt entirely on device and returns the structured `ReceiptReading`.
///
/// Two implementations: `FoundationModelsReceiptReader` (Vision OCR → Apple
/// Intelligence guided generation) for real devices, and `MockReceiptReader`
/// (deterministic, no model) for previews, tests, and unsupported hardware.
protocol ReceiptReader: Sendable {
    func read(_ input: ReceiptInput) async throws -> ReceiptReading
}

enum ReceiptReaderError: LocalizedError {
    /// Apple Intelligence is unavailable on this device (not eligible, disabled,
    /// or the model isn't downloaded yet).
    case modelUnavailable(String)
    /// No legible text was found in the capture.
    case noTextFound
    /// The capture couldn't be decoded into an image for OCR.
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason): "Apple Intelligence is unavailable: \(reason)"
        case .noTextFound: "Couldn't find any readable text on this receipt."
        case .unreadableImage: "Couldn't read this file as an image."
        }
    }
}
