import UIKit

/// Downloads and caches station logos for the lock screen and CarPlay.
actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let result = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: result.0) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

extension UIImage {
    /// Aspect-fits the image into a square, so logos of any shape look tidy in lists.
    func squareThumbnail(side: CGFloat) -> UIImage {
        let canvas = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = false
        let ratio = min(side / max(size.width, 1), side / max(size.height, 1))
        let drawn = CGSize(width: size.width * ratio, height: size.height * ratio)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}
