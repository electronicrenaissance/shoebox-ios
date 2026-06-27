import SwiftUI
import PhotosUI
import VisionKit

/// Shared state for adding a receipt, so the "+" affordance works identically from
/// every screen (Summary, Receipts, empty states). The presentation and ingest are
/// hosted once at the app root; views just call these triggers.
@MainActor
@Observable
final class ImportCoordinator {
    var isScanning = false
    var isPickingPhotos = false
    var isImportingPDFs = false
    var photoItems: [PhotosPickerItem] = []

    /// The document scanner only exists where there's a camera (not on Mac).
    var canScan: Bool { VNDocumentCameraViewController.isSupported }

    func scanDocument() { isScanning = true }
    func choosePhotos() { isPickingPhotos = true }
    func importPDFs() { isImportingPDFs = true }
}
