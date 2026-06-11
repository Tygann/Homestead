import CryptoKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
actor HomeAssistantImageCache {
    static let shared = HomeAssistantImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let directoryURL: URL?
    private var inFlightRequests: [NSString: Task<UIImage?, Never>] = [:]

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
    }

    func image(for request: URLRequest) async -> UIImage? {
        let key = cacheKey(for: request) as NSString

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        if let diskImage = loadImageFromDisk(for: key as String) {
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }

        if let inFlightRequest = inFlightRequests[key] {
            return await inFlightRequest.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    return nil
                }

                return image
            } catch {
                return nil
            }
        }

        inFlightRequests[key] = task
        let image = await task.value
        inFlightRequests[key] = nil

        if let image {
            cache.setObject(image, forKey: key)
            saveImageToDisk(image, for: key as String)
        }

        return image
    }

    private func cacheKey(for request: URLRequest) -> String {
        let url = request.url?.absoluteString ?? "unknown-url"
        return "\(request.httpMethod ?? "GET")|\(url)"
    }

    private func loadImageFromDisk(for key: String) -> UIImage? {
        do {
            let url = try cacheFileURL(for: key)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func saveImageToDisk(_ image: UIImage, for key: String) {
        do {
            let url = try cacheFileURL(for: key)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            guard let data = image.pngData() else {
                return
            }

            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private func cacheFileURL(for key: String) throws -> URL {
        try cacheDirectoryURL()
            .appendingPathComponent(cacheFileName(for: key), isDirectory: false)
    }

    private func cacheDirectoryURL() throws -> URL {
        if let directoryURL {
            return directoryURL
        }

        return try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Homestead", isDirectory: true)
        .appendingPathComponent("HomeAssistantImageCache", isDirectory: true)
    }

    private func cacheFileName(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(digest).png"
    }
}
#endif
