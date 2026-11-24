import PocketCastsDataModel
import PocketCastsServer
import UIKit
import XCTest

@testable import podcasts

@MainActor
final class AppResetTests: XCTestCase {
    func testResetClearsLibraryFilesHistoryAndSettingsAndAllowsStartingAgain() async throws {
        let dataManager = DataManager.shared
        let fileManager = FileManager.default
        let podcast = Podcast()
        podcast.uuid = UUID().uuidString
        podcast.title = "Reset Test Podcast"
        dataManager.save(podcast: podcast)
        let episode = Episode()
        episode.uuid = UUID().uuidString
        episode.podcastUuid = podcast.uuid
        episode.podcast_id = podcast.id
        episode.title = "Reset Test Episode"
        episode.downloadUrl = "https://example.com/episode.mp3"
        episode.fileType = "mp3"
        episode.episodeStatus = DownloadStatus.downloaded.rawValue
        episode.playedUpTo = 120
        episode.keepEpisode = true
        dataManager.save(episode: episode)
        PlaybackManager.shared.queue.add(episode: episode, fireNotification: false)
        dataManager.snapshotUpNext()

        let imported = UserEpisode()
        imported.uuid = UUID().uuidString
        imported.title = "Imported Audio"
        dataManager.save(episode: imported)
        let playlist = EpisodeFilter.makeDefault()
        playlist.playlistName = "My Playlist"
        dataManager.save(playlist: playlist)
        try dataManager.transcripts.save(episodeUuid: episode.uuid, text: "Private transcript", passages: [
            TranscriptPassage(id: episode.uuid + "/0", episodeUuid: episode.uuid, text: "Private transcript", speaker: nil, startTime: nil, endTime: nil)
        ])

        let groupDirectory = try XCTUnwrap(fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.GroupUserDefaults.groupContainerId))
        let files = [
            URL(fileURLWithPath: DownloadManager.shared.path(for: episode)),
            URL(fileURLWithPath: DownloadManager.shared.tempDownloadFolder).appendingPathComponent("reset-test.tmp"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("reset-test.backup"),
            groupDirectory.appendingPathComponent("opml.opml")
        ]
        for file in files { try Data("local app data".utf8).write(to: file) }

        UserDefaults.standard.set("private value", forKey: "AppResetTest")
        SharedConstants.GroupUserDefaults.defaults.set("private value", forKey: "AppResetTest")
        Settings.libraryType = .list
        SearchHistoryModel.shared.add(searchTerm: "Private search")
        StatsManager.shared.addTotalListeningTime(120)

        let appDelegate = AppDelegate()
        do {
            try await appDelegate.resetApp()
        } catch {
            XCTFail("Reset failed: \(error)")
            return
        }

        XCTAssertTrue(dataManager.allPodcasts(includeUnsubscribed: true).isEmpty)
        XCTAssertNil(dataManager.findEpisode(uuid: episode.uuid))
        XCTAssertNil(dataManager.findUserEpisode(uuid: imported.uuid))
        XCTAssertNil(dataManager.findPlaylist(uuid: playlist.uuid))
        XCTAssertTrue(dataManager.allUpNextEpisodes().isEmpty)
        XCTAssertTrue(dataManager.upNextHistoryEntries().isEmpty)
        XCTAssertNil(PlaybackManager.shared.currentEpisode)
        XCTAssertTrue(try dataManager.transcripts.search("private").isEmpty)
        XCTAssertTrue(SearchHistoryModel.shared.entries.isEmpty)
        XCTAssertEqual(StatsManager.shared.totalListeningTime(), 0)
        XCTAssertEqual(Settings.libraryType, .threeByThree)
        XCTAssertNil(UserDefaults.standard.object(forKey: "AppResetTest"))
        XCTAssertNil(SharedConstants.GroupUserDefaults.defaults.object(forKey: "AppResetTest"))
        for file in files { XCTAssertFalse(fileManager.fileExists(atPath: file.path), file.path) }

        // The database and download directories must still work without relaunching.
        let newPodcast = Podcast()
        newPodcast.uuid = UUID().uuidString
        dataManager.save(podcast: newPodcast)
        XCTAssertEqual(dataManager.allPodcasts(includeUnsubscribed: false).map(\.uuid), [newPodcast.uuid])
        try Data("new download".utf8).write(to: files[0])
        XCTAssertTrue(fileManager.fileExists(atPath: files[0].path))
        try fileManager.removeItem(at: files[0])
        try dataManager.deleteAllData()
    }
}
