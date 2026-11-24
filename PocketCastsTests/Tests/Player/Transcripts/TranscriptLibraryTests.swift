import XCTest
@testable import PocketCastsDataModel
@testable import podcasts

final class TranscriptLibraryTests: XCTestCase {
    func testIndexingRetriesFailedDownloadsAndRetrievesSavedTranscriptsOffline() async throws {
        let dataManager = DataManager.newTestDataManager()
        let podcast = Podcast()
        podcast.uuid = UUID().uuidString
        podcast.subscribed = 1
        dataManager.save(podcast: podcast)
        let episodes = (0..<3).map { _ in
            let episode = Episode()
            episode.uuid = UUID().uuidString
            episode.podcastUuid = podcast.uuid
            episode.podcast_id = podcast.id
            dataManager.save(episode: episode)
            return episode
        }
        let loader = TranscriptLoader(unavailable: episodes[1].uuid, failing: episodes[2].uuid)
        let library = TranscriptLibrary(dataManager: dataManager, load: { try await loader.load($0) })

        await library.indexLibrary()
        let coverage = try dataManager.transcripts.coverage()
        XCTAssertEqual(coverage.indexed, 1)
        XCTAssertEqual(coverage.unchecked, 1)
        XCTAssertEqual(try dataManager.transcripts.episodesToIndex().map(\.uuid), [episodes[2].uuid])

        await loader.restoreConnection()
        await library.indexLibrary()
        XCTAssertEqual(try dataManager.transcripts.coverage().indexed, 2)
        XCTAssertEqual(try dataManager.transcripts.coverage().unchecked, 0)
        XCTAssertEqual(try dataManager.transcripts.search("solar power").count, 2)

        let offlineLibrary = TranscriptLibrary(dataManager: dataManager, load: { _ in throw URLError(.notConnectedToInternet) })
        let text = try await offlineLibrary.transcript(episodeUuid: episodes[0].uuid)
        XCTAssertEqual(text, "We discussed solar power.")
    }

    private actor TranscriptLoader {
        let unavailable: String
        let failing: String
        var connected = false

        init(unavailable: String, failing: String) {
            self.unavailable = unavailable
            self.failing = failing
        }

        func restoreConnection() { connected = true }

        func load(_ episode: TranscriptEpisode) throws -> TranscriptModel {
            if episode.uuid == unavailable { throw TranscriptError.notAvailable }
            if episode.uuid == failing && !connected { throw URLError(.notConnectedToInternet) }
            return try XCTUnwrap(TranscriptModel.makeModel(from: "We discussed solar power.", format: .textPlain))
        }
    }
}
