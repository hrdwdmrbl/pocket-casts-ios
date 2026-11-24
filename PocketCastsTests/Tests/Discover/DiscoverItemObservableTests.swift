import Combine
import XCTest
@testable import podcasts
@testable import PocketCastsServer
@testable import PocketCastsUtils

final class DiscoverItemObservableTests: XCTestCase {

    class MockServerHandler: DiscoverServerHandling {
        func discoverCategories(source: String) async -> [DiscoverCategory] {
            return [
                DiscoverCategory(id: 1, name: "Tech"),
                DiscoverCategory(id: 2, name: "News"),
                DiscoverCategory(id: 3, name: "Science")
            ]
        }

        func discoverPodcastList(source: String, completion: @escaping (PodcastList?) -> Void) {
            completion(nil)
        }

        func discoverPodcastCollection(source: String, completion: @escaping (PodcastCollection?) -> Void) {
            completion(nil)
        }

        func discoverCategories(source: String, completion: @escaping ([DiscoverCategory]?) -> Void) {
            Task { completion(await discoverCategories(source: source)) }
        }

        func discoverCategoryDetails(source: String, completion: @escaping (DiscoverCategoryDetails?) -> Void) {
            completion(nil)
        }

        func discoverItem<T>(_ source: String?, type: T.Type) -> AnyPublisher<T, Error> where T: Decodable {
            Empty().eraseToAnyPublisher()
        }
    }

    func testPopularFiltering() async {
        class Mock: MockServerHandler {
        }

        let observable = CategoriesSelectorViewController.DiscoverItemObservable(serverHandler: Mock())
        observable.item = DiscoverItem(
            id: "item2",
            title: "Test 2",
            source: "mockSource",
            regions: [],
            popular: [1],
            authenticated: false
        )

        let result = await observable.load()
        XCTAssertEqual(result?.prioritized.map(\.id), [1])
    }
}
