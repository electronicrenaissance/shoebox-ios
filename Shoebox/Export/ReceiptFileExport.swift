import SwiftUI
import UniformTypeIdentifiers

extension Receipt {
    /// UTType of the stored original (image or PDF), from its MIME type.
    var originalContentType: UTType {
        switch mimeType {
        case "application/pdf": .pdf
        case "image/png": .png
        case "image/webp": .webP
        case "image/jpeg": .jpeg
        default: .data
        }
    }

    /// Write the original capture to a temp file (named like the original) so it
    /// can be shared. Returns nil if there's no stored file.
    func writeTemporaryFile() -> URL? {
        guard let data = imageData else { return nil }
        let fallback = "Receipt.\(originalContentType.preferredFilenameExtension ?? "dat")"
        let name = fileName.isEmpty ? fallback : fileName
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Wraps the original receipt bytes for `.fileExporter` (the Mac Save panel).
struct ReceiptFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jpeg, .png, .webP, .pdf, .image, .data] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
