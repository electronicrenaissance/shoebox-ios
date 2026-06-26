import Foundation
import SwiftData
import os

/// Orchestrates the capture → read → store loop. A new capture is persisted
/// immediately in a `processing` state (so it appears in the list right away and
/// is never lost), then read on device in the background; the result is applied
/// to the same record. A thrown read lands the receipt in `failed` (PRD FR-AI6).
///
/// Reads run **one at a time** through a serial queue so importing a big batch of
/// images/PDFs doesn't spawn dozens of concurrent on-device model sessions. The
/// queue is LIFO (newest-enqueued first); the still-processing rows sit at the
/// bottom of the list and each finished receipt rises into its date slot above.
@MainActor
@Observable
final class ReceiptProcessor {
    private let reader: ReceiptReader
    private let logger = Logger(subsystem: "ca.electronicrenaissance.shoebox", category: "processing")

    private struct Job {
        let input: ReceiptInput
        let receiptID: PersistentIdentifier
        let context: ModelContext
    }
    private var queue: [Job] = []
    private var isDraining = false

    init(reader: ReceiptReader) {
        self.reader = reader
    }

    /// Persist a new capture and queue the background read. Returns the new
    /// receipt's id so callers can navigate to it.
    @discardableResult
    func ingest(_ input: ReceiptInput, into context: ModelContext) -> PersistentIdentifier {
        let receipt = Receipt(
            fileName: input.fileName,
            mimeType: input.mimeType,
            imageData: input.data
        )
        context.insert(receipt)
        save(context)

        let id = receipt.persistentModelID
        enqueue(Job(input: input, receiptID: id, context: context))
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
        enqueue(Job(input: input, receiptID: receipt.persistentModelID, context: context))
    }

    // MARK: Serial queue

    private func enqueue(_ job: Job) {
        queue.append(job)
        Task { await drain() }
    }

    private func drain() async {
        guard !isDraining else { return }
        isDraining = true
        // No `await` between the emptiness check and resetting the flag, so the
        // main actor can't lose a late enqueue (it'd be seen by the loop).
        // removeLast → process the newest-enqueued job first (top of the list).
        while !queue.isEmpty {
            let job = queue.removeLast()
            await process(job)
        }
        isDraining = false
    }

    private func process(_ job: Job) async {
        let context = job.context

        // Generate the list thumbnail here (off the import loop) so a big batch
        // creates rows instantly and thumbnails fill in as each is read.
        if let receipt = context.model(for: job.receiptID) as? Receipt, receipt.thumbnailData == nil {
            receipt.thumbnailData = Thumbnailer.makeThumbnail(from: job.input)
            save(context)
        }

        do {
            let reading = try await reader.read(job.input)
            guard let receipt = context.model(for: job.receiptID) as? Receipt else { return }
            receipt.apply(reading)
            save(context)
            logger.info("Read receipt \(receipt.id, privacy: .public) → \(receipt.status.rawValue, privacy: .public)")
        } catch {
            guard let receipt = context.model(for: job.receiptID) as? Receipt else { return }
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
