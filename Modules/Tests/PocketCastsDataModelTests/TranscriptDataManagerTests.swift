import XCTest
@testable import PocketCastsDataModel

final class TranscriptDataManagerTests: DataManagerTestCase {
    func testSearchScopesIncludeArchivedEpisodesAndExcludeRemovedSubscriptions() throws {
        try runWithDataManager { dataManager in
            let first = self.createTestPodcast(title: "Science", dataManager: dataManager)
            let second = self.createTestPodcast(title: "Engineering", dataManager: dataManager)
            let archived = self.createTestEpisode(podcast: first, archived: true, dataManager: dataManager)
            let other = self.createTestEpisode(podcast: second, dataManager: dataManager)
            let transcripts = dataManager.transcripts
            for episode in [archived, other] {
                try transcripts.save(episodeUuid: episode.uuid, text: "Nuclear power", passages: [
                    TranscriptPassage(id: episode.uuid + "/0", episodeUuid: episode.uuid, text: "Nuclear power", speaker: "Alex", startTime: 12, endTime: 15)
                ])
            }

            XCTAssertEqual(try transcripts.search("nuclear power").count, 2)
            let matches = try transcripts.search("NUCLEAR power", podcastUuid: first.uuid)
            XCTAssertEqual(matches.map(\.episodeUuid), [archived.uuid])
            XCTAssertEqual(matches.first?.speaker, "Alex")
            XCTAssertEqual(matches.first?.startTime, 12)
            XCTAssertEqual(try transcripts.search("power", episodeUuid: other.uuid).map(\.episodeUuid), [other.uuid])
            XCTAssertTrue(try transcripts.search("power", podcastUuid: first.uuid, episodeUuid: other.uuid).isEmpty)
            XCTAssertTrue(try transcripts.search("\" OR * -").isEmpty)

            second.subscribed = 0
            dataManager.save(podcast: second)
            XCTAssertEqual(try transcripts.search("power").map(\.episodeUuid), [archived.uuid])
            XCTAssertNil(try transcripts.text(episodeUuid: other.uuid))
            XCTAssertNil(try transcripts.passage(id: other.uuid + "/0"))
            XCTAssertTrue(dataManager.findEpisode(uuid: archived.uuid)!.archived)
        }
    }

    func testReindexingReplacesSearchResultsAndDeletingEpisodeRemovesTranscript() throws {
        try runWithDataManager { dataManager in
            let podcast = self.createTestPodcast(dataManager: dataManager)
            let episode = self.createTestEpisode(podcast: podcast, dataManager: dataManager)
            let transcripts = dataManager.transcripts
            for text in ["old advertisement", "retained discussion"] {
                try transcripts.save(episodeUuid: episode.uuid, text: text, passages: [
                    TranscriptPassage(id: episode.uuid + "/0", episodeUuid: episode.uuid, text: text, speaker: nil, startTime: nil, endTime: nil)
                ])
            }
            XCTAssertTrue(try transcripts.search("advertisement").isEmpty)
            XCTAssertEqual(try transcripts.text(episodeUuid: episode.uuid), "retained discussion")
            XCTAssertEqual(try transcripts.search("discussion").count, 1)
            dataManager.delete(episodeUuid: episode.uuid)
            XCTAssertNil(try transcripts.text(episodeUuid: episode.uuid))
            XCTAssertTrue(try transcripts.search("discussion").isEmpty)
        }
    }

    func testCoverageDistinguishesMissingTranscriptsFromUncheckedEpisodesAndSurvivesDataWipe() throws {
        try runWithDataManager { dataManager in
            let podcast = self.createTestPodcast(dataManager: dataManager)
            let indexed = self.createTestEpisode(podcast: podcast, dataManager: dataManager)
            let unavailable = self.createTestEpisode(podcast: podcast, dataManager: dataManager)
            let pending = self.createTestEpisode(podcast: podcast, dataManager: dataManager)
            let transcripts = dataManager.transcripts
            try transcripts.save(episodeUuid: indexed.uuid, text: "Café", passages: [
                TranscriptPassage(id: indexed.uuid + "/0", episodeUuid: indexed.uuid, text: "Café", speaker: nil, startTime: nil, endTime: nil)
            ])
            try transcripts.save(episodeUuid: unavailable.uuid, text: nil, passages: [])
            let coverage = try transcripts.coverage()
            XCTAssertEqual(coverage.total, 3)
            XCTAssertEqual(coverage.indexed, 1)
            XCTAssertEqual(coverage.unchecked, 1)
            XCTAssertEqual(try transcripts.episodesToIndex().map(\.uuid), [pending.uuid])
            XCTAssertEqual(try transcripts.search("cafe").count, 1)

            try dataManager.deleteAllData()
            XCTAssertEqual(try transcripts.coverage().total, 0)
            XCTAssertTrue(try transcripts.search("cafe").isEmpty)
            let newPodcast = self.createTestPodcast(dataManager: dataManager)
            let newEpisode = self.createTestEpisode(podcast: newPodcast, dataManager: dataManager)
            try transcripts.save(episodeUuid: newEpisode.uuid, text: "hello", passages: [
                TranscriptPassage(id: newEpisode.uuid + "/0", episodeUuid: newEpisode.uuid, text: "hello", speaker: nil, startTime: nil, endTime: nil)
            ])
            XCTAssertEqual(try transcripts.search("hello").count, 1)
        }
    }
}
