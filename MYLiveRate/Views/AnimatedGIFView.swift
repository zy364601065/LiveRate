import Kingfisher
import SwiftUI
import UIKit

struct KingfisherGIFView: View {
    let fileName: String
    var contentMode: UIView.ContentMode = .scaleAspectFill

    var body: some View {
        Group {
            if let fileURL = Bundle.main.gifResourceURL(named: fileName) {
                let provider = LocalFileImageDataProvider(
                    fileURL: fileURL,
                    cacheKey: "bundle-gif-\(fileURL.lastPathComponent)"
                )

                KFAnimatedImage(source: .provider(provider))
                    .configure { imageView in
                        imageView.backgroundColor = .clear
                        imageView.clipsToBounds = true
                        imageView.contentMode = contentMode
                    }
                    .cancelOnDisappear(true)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }
}

struct KingfisherRemoteGIFView: View {
    let url: URL?
    var contentMode: UIView.ContentMode = .scaleAspectFill

    var body: some View {
        Group {
            if let url {
                KFAnimatedImage(url)
                    .configure { imageView in
                        imageView.backgroundColor = .clear
                        imageView.clipsToBounds = true
                        imageView.contentMode = contentMode
                    }
                    .cancelOnDisappear(true)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }
}

private extension Bundle {
    func gifResourceURL(named resourceName: String) -> URL? {
        let resourcePath = resourceName as NSString
        let fileName = resourcePath.lastPathComponent
        let baseName = resourcePath.deletingPathExtension
        let fileExtension = resourcePath.pathExtension

        if !fileExtension.isEmpty {
            if let directURL = url(forResource: baseName, withExtension: fileExtension) {
                return directURL
            }
            if let lowercasedURL = url(forResource: baseName, withExtension: fileExtension.lowercased()) {
                return lowercasedURL
            }
            if let uppercasedURL = url(forResource: baseName, withExtension: fileExtension.uppercased()) {
                return uppercasedURL
            }
        }

        if fileExtension.isEmpty {
            if let directURL = url(forResource: fileName, withExtension: nil) {
                return directURL
            }
            if let gifURL = url(forResource: fileName, withExtension: "gif") {
                return gifURL
            }
        }

        guard let rootURL = resourceURL,
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
}
