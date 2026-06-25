import SwiftUI
import VisionKit

/// SwiftUI wrapper around VisionKit's document camera. Returns the first scanned
/// page as JPEG data (receipts are single-page in the MVP).
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) { self.parent = parent }

        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Extract Sendable `Data` before hopping onto the main actor so the
            // non-Sendable `scan` isn't sent across the boundary. VisionKit
            // already invokes this on the main thread.
            let data: Data? = scan.pageCount > 0
                ? scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.8)
                : nil
            MainActor.assumeIsolated {
                if let data { parent.onScan(data) } else { parent.onCancel() }
            }
        }

        nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            MainActor.assumeIsolated { parent.onCancel() }
        }

        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            MainActor.assumeIsolated { parent.onCancel() }
        }
    }
}
