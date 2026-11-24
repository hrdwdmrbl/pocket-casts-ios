import Combine
import Foundation
import PocketCastsUtils

/// The Discover network calls, behind a protocol so callers can be handed canned data.
///
/// `DiscoverServerHandler.shared` is the production implementation; previews and tests inject
/// their own. Every method mirrors one section type of the Discover page.
public protocol DiscoverServerHandling {
    func discoverPodcastList(source: String, completion: @escaping (PodcastList?) -> Void)
    func discoverPodcastCollection(source: String, completion: @escaping (PodcastCollection?) -> Void)
    func discoverCategories(source: String, completion: @escaping ([DiscoverCategory]?) -> Void)
    func discoverCategories(source: String) async -> [DiscoverCategory]
    func discoverCategoryDetails(source: String, completion: @escaping (DiscoverCategoryDetails?) -> Void)
    func discoverItem<T>(_ source: String?, type: T.Type) -> AnyPublisher<T, Error> where T: Decodable
}

public class DiscoverServerHandler: DiscoverServerHandling {
    enum DiscoverServerError: Error {
        case unknown
        case badRequest
    }

    public static let shared = DiscoverServerHandler()

    public private(set) lazy var discoveryCache: URLCache = {
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 5 * 1024 * 1024, diskPath: "discovery")
        return cache
    }()

    /// Valid image sizes: 130,140,200,210,280,340,400,420,680,960
    public class func thumbnailUrlString(forPodcast podcast: String, size: Int) -> String {
        "\(ServerConstants.Urls.discover())images/\(size)/\(podcast).jpg"
    }

    public enum DiscoverType {
        case discover
        case search

        var path: String {
            var contentPath: String = "ios"
            #if os(tvOS)
            contentPath = "tv"
            #endif

            switch self {
            case .discover:
                contentPath.append("/content_v2.json")
            case .search:
                contentPath.append("/content_v4_search.json")
            }

            return contentPath
        }
    }

    public func discoverPage(type: DiscoverType = .discover) async -> (DiscoverLayout?, Bool) {
        let contentPath = type.path
        return await discoverPage(path: contentPath)
    }

    private func discoverPage(path contentPath: String) async -> (DiscoverLayout?, Bool) {
        return await withCheckedContinuation { continuation in
            discoverRequest(path: ServerConstants.Urls.discover() + contentPath, type: DiscoverLayout.self) { discoverItems, cachedResponse in
                continuation.resume(returning: (discoverItems, cachedResponse))
            }
        }
    }

    public func discoverPage(completion: @escaping (DiscoverLayout?, Bool) -> Void) {
        Task {
            let page = await discoverPage()
            completion(page.0, page.1)
        }
    }

    public func discoverPodcastList(source: String, completion: @escaping (PodcastList?) -> Void) {
        discoverRequest(path: source, type: PodcastList.self) { podcastList, _ in
            completion(podcastList)
        }
    }

    public func discoverCategories(source: String, completion: @escaping ([DiscoverCategory]?) -> Void) {
        discoverRequest(path: source, type: [DiscoverCategory].self) { categories, _ in
            completion(categories)
        }
    }

    public func discoverCategories(source: String) async -> [DiscoverCategory] {
        await withCheckedContinuation { continuation in
            discoverCategories(source: source) { result in
                continuation.resume(returning: result ?? [])
            }
        }
    }

    public func discoverCategoryDetails(source: String, completion: @escaping (DiscoverCategoryDetails?) -> Void) {
        discoverRequest(path: source, type: DiscoverCategoryDetails.self) { categoryDetails, _ in
            completion(categoryDetails)
        }
    }

    public func discoverCategoryDetails(source: String) async -> DiscoverCategoryDetails? {
        await withCheckedContinuation { continuation in
            discoverCategoryDetails(source: source) { result in
                continuation.resume(returning: result)
            }
        }
    }

    public func discoverPodcastCollection(source: String, completion: @escaping (PodcastCollection?) -> Void) {
        discoverRequest(path: source, type: PodcastCollection.self) { podcastCollection, _ in
            completion(podcastCollection)
        }
    }

    public func discoverPodcastCollection(source: String) async -> PodcastCollection? {
        await withCheckedContinuation { continuation in
            discoverPodcastCollection(source: source) { result in
                continuation.resume(returning: result)
            }
        }
    }

    public func discoverItem<T>(_ source: String?, type: T.Type) -> AnyPublisher<T, Error> where T: Decodable {
        guard let source else {
            return Fail(error: DiscoverServerError.badRequest).eraseToAnyPublisher()
        }

        return Future { [unowned self] promise in
            self.discoverRequest(path: source, type: type) { discoverList, _ in
                if let discoverList {
                    promise(.success(discoverList))
                } else {
                    promise(.failure(DiscoverServerError.unknown))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    public func cachedResponse(for path: String) -> CachedURLResponse? {
        let url = ServerHelper.asUrl(path)
        let request = URLRequest(url: url)
        if let cachedResponse = discoveryCache.cachedResponse(for: request),
           let expiryDate = cachedResponse.response.cacheExpiryDate(),
           expiryDate.timeIntervalSinceNow > 0 {
            return cachedResponse
        }
        return nil
    }

    private func performDiscoverRequest(
        path: String,
        completion: @escaping (Data?, URLResponse?, Error?, Bool) -> Void
    ) {
        let url = ServerHelper.asUrl(path)
        var request = URLRequest(url: url)
        request.addLocalizationHeaders()

        if let cachedResponse = cachedResponse(for: path) {
            completion(cachedResponse.data, cachedResponse.response, nil, true)
            return
        }

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            completion(data, response, error, false)
        }).resume()
    }

    private func decodeDiscoverResponse<T>(
        data: Data,
        response: URLResponse,
        cacheRequest: URLRequest,
        useCache: Bool,
        type: T.Type
    ) -> T? where T: Decodable {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode(type, from: data)
            if useCache {
                let responseToCache = CachedURLResponse(response: response, data: data)
                discoveryCache.storeCachedResponse(responseToCache, for: cacheRequest)
            }
            return decoded
        } catch {
            if useCache {
                discoveryCache.removeCachedResponse(for: cacheRequest)
            }
            return nil
        }
    }

    func discoverRequest<T>(
        path: String,
        type: T.Type,
        completion: @escaping (T?, Bool) -> Void
    ) where T: Decodable {
        let url = ServerHelper.asUrl(path)
        let request = URLRequest(url: url)

        performDiscoverRequest(path: path) { [weak self] data, response, error, useCache in
            guard
                let self,
                let data,
                let response,
                error == nil
            else {
                completion(nil, false)
                return
            }

            let decoded = self.decodeDiscoverResponse(
                data: data,
                response: response,
                cacheRequest: request,
                useCache: true,
                type: type
            )
            completion(decoded, useCache)
        }
    }
}
