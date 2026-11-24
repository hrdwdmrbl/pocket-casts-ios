@testable import PocketCastsDataModel
import XCTest

final class SmartPlaylistArchivedEpisodesTests: DataManagerTestCase {
    func testIncludingArchivedEpisodesPersistsAndUpdatesPlaylistResults() throws {
        try runWithDataManager { dataManager in
            let podcast = self.createTestPodcast(dataManager: dataManager)
            let archivedPodcast = self.createTestPodcast(dataManager: dataManager)
            let excludedPodcast = self.createTestPodcast(dataManager: dataManager)
            let visible = self.createTestEpisode(podcast: podcast, dataManager: dataManager)
            let archived = self.createTestEpisode(podcast: podcast, archived: true, dataManager: dataManager)
            let archivedOnly = self.createTestEpisode(podcast: archivedPodcast, title: "Searchable episode", archived: true, dataManager: dataManager)
            self.createTestEpisode(podcast: excludedPodcast, archived: true, dataManager: dataManager)

            let playlist = EpisodeFilter.makeDefault()
            playlist.filterAllPodcasts = false
            playlist.podcastUuids = [podcast.uuid, archivedPodcast.uuid].joined(separator: ",")
            dataManager.save(playlist: playlist)

            let defaultPlaylist = try XCTUnwrap(dataManager.findPlaylist(uuid: playlist.uuid))
            XCTAssertEqual(dataManager.playlistEpisodes(for: defaultPlaylist).map(\.uuid), [visible.uuid])
            XCTAssertEqual(dataManager.allPlaylistEpisodeCount(for: defaultPlaylist, episodeUuidToAdd: nil), 1)

            playlist.showArchivedEpisodes = true
            dataManager.save(playlist: playlist)
            let savedPlaylist = try XCTUnwrap(dataManager.findPlaylist(uuid: playlist.uuid))

            XCTAssertEqual(Set(dataManager.playlistEpisodes(for: savedPlaylist).map(\.uuid)), Set([visible.uuid, archived.uuid, archivedOnly.uuid]))
            XCTAssertEqual(dataManager.allPlaylistEpisodeCount(for: savedPlaylist, episodeUuidToAdd: nil), 3)
            XCTAssertEqual(dataManager.episodeCount(for: savedPlaylist, episodeUuidToAdd: nil), 3)
            XCTAssertEqual(dataManager.playlistEpisodeCount(for: savedPlaylist, episodeUuidToAdd: nil), 1)
            XCTAssertEqual(dataManager.playlistArchivedEpisodeCount(for: savedPlaylist, episodeUuidToAdd: nil), 2)
            XCTAssertTrue(try XCTUnwrap(dataManager.findEpisode(uuid: archived.uuid)).archived)

            let artworkQuery = PlaylistQueryBuilder.query(clause: .firstDistinctEpisodes, for: savedPlaylist, limit: 4)
            let artworkEpisodes = dataManager.findPlaylistEpisodesWhere(query: artworkQuery, arguments: nil)
            XCTAssertEqual(Set(artworkEpisodes.map(\.podcastUuid)), Set([podcast.uuid, archivedPodcast.uuid]))

            let searchQuery = PlaylistQueryBuilder.query(clause: .episode, for: savedPlaylist, searchTerm: "Searchable")
            XCTAssertEqual(dataManager.findPlaylistEpisodesWhere(query: searchQuery, arguments: nil).map(\.uuid), [archivedOnly.uuid])

            savedPlaylist.showArchivedEpisodes = false
            dataManager.save(playlist: savedPlaylist)
            let disabledPlaylist = try XCTUnwrap(dataManager.findPlaylist(uuid: playlist.uuid))
            XCTAssertEqual(dataManager.playlistEpisodes(for: disabledPlaylist).map(\.uuid), [visible.uuid])
            XCTAssertEqual(dataManager.allPlaylistEpisodeCount(for: disabledPlaylist, episodeUuidToAdd: nil), 1)
        }
    }

    func testArchivedEpisodesStillMatchTheOtherSmartPlaylistRules() throws {
        try runWithDataManager { dataManager in
            let podcast = self.createTestPodcast(dataManager: dataManager)
            let unplayed = self.createTestEpisode(podcast: podcast, playingStatus: PlayingStatus.notPlayed.rawValue, archived: true, dataManager: dataManager)
            self.createTestEpisode(podcast: podcast, playingStatus: PlayingStatus.completed.rawValue, archived: true, dataManager: dataManager)

            let playlist = EpisodeFilter.makeDefault()
            playlist.showArchivedEpisodes = true
            playlist.filterFinished = false

            XCTAssertEqual(dataManager.playlistEpisodes(for: playlist).map(\.uuid), [unplayed.uuid])
            XCTAssertEqual(dataManager.allPlaylistEpisodeCount(for: playlist, episodeUuidToAdd: nil), 1)

            let widgetConditions = PlaylistQueryBuilder.queryFor(filter: playlist, episodeUuidToAdd: nil, limit: 0)
            let widgetQuery = "SELECT * FROM \(DataManager.episodeTableName) WHERE \(widgetConditions)"
            XCTAssertEqual(dataManager.findPlaylistEpisodesWhere(query: widgetQuery, arguments: nil).map(\.uuid), [unplayed.uuid])
        }
    }
}
