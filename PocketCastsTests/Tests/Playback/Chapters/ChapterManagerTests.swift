import CoreMedia
import XCTest

@testable import podcasts
@testable import PocketCastsDataModel
@testable import PocketCastsServer
@testable import PocketCastsUtils

class ChapterManagerTests: XCTestCase {

    /// Update the current chapter given a TimeInterval
    func testUpdateCurrentChapterBasedOnTime() async {
        let parserMock = PodcastChapterParserMock()
        let showInfoCoordinatorMock = ShowInfoCoordinatorMock()
        parserMock.chapters = [
            chapterInfo(startTime: 0, duration: 100),
            chapterInfo(startTime: 101, duration: 200),
            chapterInfo(startTime: 201, duration: 300),
            chapterInfo(startTime: 301, duration: 400),
            chapterInfo(startTime: 401, duration: 500),
            chapterInfo(startTime: 501, duration: 600)
        ]
        let chapterManager = ChapterManager(chapterParser: parserMock, showInfoCoordinator: showInfoCoordinatorMock)
        await chapterManager.parseChapters(episode: EpisodeMock(), duration: 600)

        chapterManager.updateCurrentChapter(time: 10)

        XCTAssertEqual(chapterManager.currentChapters.visibleChapter, chapterInfo(startTime: 0, duration: 100))
    }

    /// Update the current chapter given a TimeInterval
    func testReturnNextVisiblePlayableChapter() async {
        let showInfoCoordinatorMock = ShowInfoCoordinatorMock()
        let parserMock = PodcastChapterParserMock()
        parserMock.chapters = [
            chapterInfo(startTime: 0, duration: 100),
            chapterInfo(startTime: 101, duration: 200),
            chapterInfo(startTime: 201, duration: 300),
            chapterInfo(startTime: 301, duration: 400),
            chapterInfo(startTime: 401, duration: 500),
            chapterInfo(startTime: 501, duration: 600)
        ]
        let chapterManager = ChapterManager(chapterParser: parserMock, showInfoCoordinator: showInfoCoordinatorMock)
        await chapterManager.parseChapters(episode: EpisodeMock(), duration: 600)
        chapterManager.updateCurrentChapter(time: 10)

        let nextVisiblePlayableChapter = chapterManager.nextVisiblePlayableChapter()

        XCTAssertEqual(nextVisiblePlayableChapter, chapterInfo(startTime: 101, duration: 200))
    }

    /// Update the current chapter given a TimeInterval
    func testReturnPreviousVisiblePlayableChapter() async {
        let showInfoCoordinatorMock = ShowInfoCoordinatorMock()
        let parserMock = PodcastChapterParserMock()
        parserMock.chapters = [
            chapterInfo(startTime: 0, duration: 100),
            chapterInfo(startTime: 101, duration: 200),
            chapterInfo(startTime: 201, duration: 300),
            chapterInfo(startTime: 301, duration: 400),
            chapterInfo(startTime: 401, duration: 500),
            chapterInfo(startTime: 501, duration: 600)
        ]
        let chapterManager = ChapterManager(chapterParser: parserMock, showInfoCoordinator: showInfoCoordinatorMock)
        await chapterManager.parseChapters(episode: EpisodeMock(), duration: 600)
        chapterManager.updateCurrentChapter(time: 450)

        let nextVisiblePlayableChapter = chapterManager.previousVisibleChapter()

        XCTAssertEqual(nextVisiblePlayableChapter, chapterInfo(startTime: 301, duration: 400))
    }

    func chapterInfo(startTime: TimeInterval, duration: TimeInterval) -> ChapterInfo {
        let chapterInfo = ChapterInfo()
        chapterInfo.startTime = CMTime(seconds: startTime, preferredTimescale: .max)
        chapterInfo.duration = duration
        return chapterInfo
    }
}

class PodcastChapterParserMock: PodcastChapterParser {
    var chapters: [ChapterInfo] = []

    override func parseRemoteFile(_ remoteUrl: String, episodeDuration: TimeInterval, completion: @escaping (([ChapterInfo]) -> Void)) {
        completion(chapters)
    }

    override func parseRemoteFile(_ remoteUrl: String, episodeDuration: TimeInterval) async -> [ChapterInfo] {
        chapters
    }
}

private class ShowInfoCoordinatorMock: ShowInfoCoordinating {
    func loadShowNotes(podcastUuid: String, episodeUuid: String) async throws -> String {
        ""
    }

    func loadEpisodeArtworkUrl(podcastUuid: String, episodeUuid: String) async throws -> URL? {
        nil
    }

    func loadChapters(podcastUuid: String, episodeUuid: String) async throws -> ([PocketCastsDataModel.Episode.Metadata.EpisodeChapter]?, [podcasts.PodcastIndexChapter]?) {
        (nil, nil)
    }

    func loadTranscriptsMetadata(podcastUuid: String, episodeUuid: String) async throws -> [Episode.Metadata.Transcript] {
        return []
    }
}

private class EpisodeMock: Episode {
    override var downloadUrl: String? {
        get { "https://pocketcasts.com/" }
        set {}
    }
}
