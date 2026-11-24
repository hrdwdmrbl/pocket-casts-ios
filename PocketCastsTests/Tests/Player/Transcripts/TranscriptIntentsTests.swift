import AppIntents
import XCTest
@testable import PocketCastsDataModel
@testable import podcasts

final class TranscriptIntentsTests: DBTestCase {
    func testSearchResultPassesItsEpisodeToGetTranscript() async throws {
        podcast.title = "Science"
        podcast.subscribed = 1
        dataManager.save(podcast: podcast)
        episode.title = "Solar Energy"
        episode.archived = true
        dataManager.save(episode: episode)
        defer { dataManager.delete(podcast: podcast) }

        try dataManager.transcripts.save(episodeUuid: episode.uuid, text: "[1:00] Alex: We discussed solar power.", passages: [
            TranscriptPassage(id: episode.uuid + "/0", episodeUuid: episode.uuid, text: "We discussed solar power.", speaker: "Alex", startTime: 60, endTime: 90)
        ])
        var search = SearchTranscriptsIntent()
        search.query = "solar power"
        search.podcast = TranscriptPodcastEntity(podcast)
        let result = try await search.perform()
        let matches = try XCTUnwrap(result.value)
        XCTAssertEqual(matches.count, 1)
        let match = try XCTUnwrap(matches.first)
        XCTAssertEqual(match.episode.id, episode.uuid)
        XCTAssertEqual(match.speaker, "Alex")
        XCTAssertEqual(match.startTime, 60)

        let restored = try await TranscriptPassageQuery().entities(for: [match.id])
        XCTAssertEqual(restored.first?.episode.id, match.episode.id)
        var get = GetTranscriptIntent()
        get.episode = match.episode
        let transcript = try await get.perform()
        let file = try XCTUnwrap(transcript.value)
        XCTAssertEqual(file.type, .plainText)
        XCTAssertEqual(String(data: file.data, encoding: .utf8), "Science\nSolar Energy\n\n[1:00] Alex: We discussed solar power.")
        XCTAssertTrue(dataManager.findEpisode(uuid: episode.uuid)!.archived)
    }
}
