import Foundation
import SwiftData

/// A captured receipt and everything the on-device pipeline learned about it.
///
/// Persisted with **SwiftData** and synced to the user's **private CloudKit
/// database**. To stay CloudKit-compatible every stored property has a default
/// value (or is optional), there are no unique constraints, and large blobs use
/// `.externalStorage`. See `docs/architecture/app-architecture.md`.
@Model
final class Receipt {
    /// Stable identity (also used for CloudKit record naming). Not a unique
    /// constraint — CloudKit forbids those — but we always generate a fresh UUID.
    var id: UUID = UUID()

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: Capture

    /// Original upload filename, e.g. `scan-2026-06-24.jpg`.
    var fileName: String = ""
    /// `image/jpeg` | `image/png` | `image/webp` | `application/pdf`.
    var mimeType: String = "image/jpeg"
    /// The original capture (image, or the rendered first page for a PDF), stored
    /// outside the database file and synced as a CloudKit asset.
    @Attribute(.externalStorage) var imageData: Data?
    /// Small list-thumbnail JPEG.
    @Attribute(.externalStorage) var thumbnailData: Data?

    // MARK: Status (raw-backed so SwiftData/CloudKit store a primitive)

    private var statusRaw: String = ReceiptStatus.processing.rawValue
    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .processing }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: Extracted details (any may be blank — illegible/absent)

    var vendor: String?
    /// Transaction / issue date.
    var date: Date?
    var total: Double?
    var currency: String = "CAD"
    /// GST/HST amount, if shown.
    var taxAmount: Double?
    /// Free-text description of what was purchased.
    var details: String?

    // Document-type identifiers (PRD FR-AI2)
    var charityRegistration: String?
    var providerName: String?

    // MARK: Validation (PRD FR-AI3)

    /// Reasons explaining a non-`acceptable` verdict; empty when acceptable.
    var validationReasons: [String] = []

    // MARK: Matched lines (PRD FR-AI4)

    /// One or more matched lines; empty while processing or if unmatched.
    var matchedLines: [TaxLineMatch] = []

    // MARK: AI baseline (PRD FR-AI5)

    /// The model's original reading as JSON, kept so we can measure how often the
    /// user corrects the AI without it being overwritten by their edits.
    var aiBaselineJSON: String?

    init(fileName: String, mimeType: String, imageData: Data?) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.imageData = imageData
        // Date is required; default to the capture day until the model extracts one.
        self.date = .now
    }

    /// Apply the on-device reader's result, stamping `updatedAt` and recording the
    /// immutable AI baseline the first time.
    func apply(_ result: ReceiptReading) {
        vendor = result.vendor.sanitized
        // Keep the existing date (capture day or a user edit) if the model didn't
        // read one — a receipt always has a date.
        if let parsed = result.parsedDate { date = parsed }
        total = result.total
        currency = result.currency.sanitized ?? "CAD"
        taxAmount = result.taxAmount
        details = result.details.sanitized
        charityRegistration = result.charityRegistration.sanitized
        providerName = result.providerName.sanitized
        validationReasons = result.reasons
        matchedLines = result.matchedLines
        status = result.status
        if aiBaselineJSON == nil {
            aiBaselineJSON = result.asJSON()
        }
        updatedAt = .now
    }
}
