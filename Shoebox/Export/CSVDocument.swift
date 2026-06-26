import SwiftUI
import UniformTypeIdentifiers

/// A CSV file document for `.fileExporter`. Writes a UTF-8 BOM ahead of the text
/// so Excel interprets the file as UTF-8 (and shows accented characters).
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
        data.append(Data(text.utf8))
        return FileWrapper(regularFileWithContents: data)
    }
}
