import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
actor HomeAssistantImageCache {
    static let shared = HomeAssistantImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlightRequests: [NSString: Task<UIImage?, Never>] = [:]

    init(directoryURL: URL? = nil) {
        let urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 128 * 1_024 * 1_024,
            directory: directoryURL
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: configuration)
    }

    func image(for request: URLRequest) async -> UIImage? {
        let key = cacheKey(for: request) as NSString

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        if let inFlightRequest = inFlightRequests[key] {
            return await inFlightRequest.value
        }

        let session = session
        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await session.data(for: request)
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
        }

        return image
    }

    private func cacheKey(for request: URLRequest) -> String {
        let url = request.url?.absoluteString ?? "unknown-url"
        return "\(request.httpMethod ?? "GET")|\(url)"
    }
}
#endif
