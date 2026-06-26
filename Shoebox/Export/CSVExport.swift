import SwiftUI
import UniformTypeIdentifiers

/// A CSV value for `ShareLink` on iPhone/iPad. Produces a `.csv` file (UTF-8 with
/// a BOM, so Excel reads accents) lazily when the user picks a share destination.
struct CSVExport: Transferable, Sendable {
    let text: String
    /// Suggested file name without extension, e.g. "Shoebox - 2024".
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            var data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
            data.append(Data(export.text.utf8))
            return data
        }
        .suggestedFileName { "\($0.filename).csv" }
    }
}
