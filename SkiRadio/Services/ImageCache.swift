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

/// Colored initials tile for stations without a logo ("RMF FM" -> "RF").
enum Monogram {
    static let palette: [UIColor] = [
        .systemOrange, .systemRed, .systemPink, .systemPurple, .systemIndigo,
        .systemBlue, .systemTeal, .systemGreen, .systemBrown,
    ]

    static func initials(for name: String) -> String {
        let words = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "♪" : letters.joined().uppercased()
    }

    /// Same station always gets the same color.
    static func color(for name: String) -> UIColor {
        let sum = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(sum) % palette.count]
    }
}

extension UIImage {
    static func monogram(for station: Station, side: CGFloat) -> UIImage {
        let color = Monogram.color(for: station.displayName)
        let text = Monogram.initials(for: station.displayName) as NSString
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [color.withAlphaComponent(0.75).cgColor, color.cgColor] as CFArray,
                locations: [0, 1]
            )
            if let gradient {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [])
            } else {
                color.setFill()
                context.fill(rect)
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: side * 0.38, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2), withAttributes: attributes)
        }
    }
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
