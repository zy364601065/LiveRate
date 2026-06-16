import SwiftUI
import UIKit
import ImageIO

struct AnimatedGIFView: UIViewRepresentable {
    let image: UIImage
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = false
        imageView.contentMode = contentMode
        imageView.image = image
        imageView.startAnimating()
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode
        if imageView.image !== image {
            imageView.image = image
        }
        if !imageView.isAnimating {
            imageView.startAnimating()
        }
    }
}

enum GIFImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func animatedImage(named resourceName: String, in bundle: Bundle = .main) -> UIImage? {
        if let cachedImage = cache.object(forKey: resourceName as NSString) {
            return cachedImage
        }

        guard let fileURL = resourceURL(named: resourceName, in: bundle),
              let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        guard frameCount > 0 else { return nil }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let frameImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
                continue
            }

            frames.append(UIImage(cgImage: frameImage))
            duration += frameDuration(at: index, source: imageSource)
        }

        guard !frames.isEmpty else { return nil }

        let totalDuration = max(duration, Double(frames.count) * 0.08)
        let animatedImage = UIImage.animatedImage(with: frames, duration: totalDuration) ?? frames.first

        guard let animatedImage else { return nil }
        cache.setObject(animatedImage, forKey: resourceName as NSString)
        return animatedImage
    }

    private static func resourceURL(named resourceName: String, in bundle: Bundle) -> URL? {
        let resourcePath = resourceName as NSString
        let fileName = resourcePath.lastPathComponent
        let baseName = resourcePath.deletingPathExtension
        let fileExtension = resourcePath.pathExtension

        if !fileExtension.isEmpty {
            if let directURL = bundle.url(forResource: baseName, withExtension: fileExtension) {
                return directURL
            }
            if let lowercasedURL = bundle.url(forResource: baseName, withExtension: fileExtension.lowercased()) {
                return lowercasedURL
            }
            if let uppercasedURL = bundle.url(forResource: baseName, withExtension: fileExtension.uppercased()) {
                return uppercasedURL
            }
        }

        if fileExtension.isEmpty {
            if let directURL = bundle.url(forResource: fileName, withExtension: nil) {
                return directURL
            }
            if let gifURL = bundle.url(forResource: fileName, withExtension: "gif") {
                return gifURL
            }
        }

        guard let rootURL = bundle.resourceURL,
              let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return nil
        }

        let targetFileName = (fileExtension.isEmpty ? "\(fileName).gif" : fileName).lowercased()

        while let nextURL = enumerator.nextObject() as? URL {
            if nextURL.lastPathComponent.lowercased() == targetFileName {
                return nextURL
            }
        }

        return nil
    }

    private static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }

        let unclampedDelay = doubleValue(gifProperties[kCGImagePropertyGIFUnclampedDelayTime])
        let delay = doubleValue(gifProperties[kCGImagePropertyGIFDelayTime])
        let frameDuration = unclampedDelay > 0 ? unclampedDelay : delay
        return frameDuration < 0.02 ? 0.1 : frameDuration
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        return 0
    }
}
