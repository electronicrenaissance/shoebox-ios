import UIKit

/// Generates small list thumbnails from a capture, off the original bytes.
enum Thumbnailer {
    /// Target longest edge for a list thumbnail, in points.
    static let maxEdge: CGFloat = 240

    static func makeThumbnail(from input: ReceiptInput) -> Data? {
        guard let cgImage = try? ReceiptOCR.rasterize(input) else { return nil }
        let source = UIImage(cgImage: cgImage)
        let scale = min(1, maxEdge / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
}
