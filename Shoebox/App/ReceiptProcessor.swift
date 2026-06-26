import Foundation
import SwiftData
import os

/// Orchestrates the capture → read → store loop. A new capture is persisted
/// immediately in a `processing` state (so it appears in the list right away and
/// is never lost), then read on device in the background; the result is applied
/// to the same record. A thrown read lands the receipt in `failed` (PRD FR-AI6).
@MainActor
@Observable
final class ReceiptProcessor {
    private let reader: ReceiptReader
    private let logger = Logger(subsystem: "ca.electronicrenaissance.shoebox", category: "processing")

    init(reader: ReceiptReader) {
        self.reader = reader
    }

    /// Persist a new capture and kick off the background read. Returns the new
    /// receipt's id so callers can navigate to it.
    @discardableResult
    func ingest(_ input: ReceiptInput, into context: ModelContext) -> PersistentIdentifier {
        let receipt = Receipt(
            fileName: input.fileName,
            mimeType: input.mimeType,
            imageData: input.data
        )
        receipt.thumbnailData = Thumbnailer.makeThumbnail(from: input)
        context.insert(receipt)
        save(context)

        let id = receipt.persistentModelID
        Task { await process(input, receiptID: id, in: context) }
        return id
    }

    /// Re-run the on-device read for an existing receipt (e.g. retry a `failed`
    /// one, or after replacing the image).
    func reprocess(_ receipt: Receipt, in context: ModelContext) {
        guard let data = receipt.imageData else { return }
        receipt.status = .processing
        receipt.updatedAt = .now
        save(context)

        let input = ReceiptInput(data: data, mimeType: receipt.mimeType, fileName: receipt.fileName)
        let id = receipt.persistentModelID
        Task { await process(input, receiptID: id, in: context) }
    }

    private func process(_ input: ReceiptInput, receiptID: PersistentIdentifier, in context: ModelContext) async {
        do {
            let reading = try await reader.read(input)
            guard let receipt = context.model(for: receiptID) as? Receipt else { return }
            receipt.apply(reading)
            save(context)
            logger.info("Read receipt \(receipt.id, privacy: .public) → \(receipt.status.rawValue, privacy: .public)")
        } catch {
            guard let receipt = context.model(for: receiptID) as? Receipt else { return }
            receipt.status = .failed
            receipt.updatedAt = .now
            save(context)
            logger.error("Failed to read receipt: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
