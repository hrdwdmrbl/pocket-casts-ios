import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class ServerRefreshManager: ServerRefreshDelegate {
    static let shared = ServerRefreshManager()
    private static let networkDataUsageRetentionPeriod: TimeInterval = 30.days
    private static let networkDataUsageCleanupInterval: TimeInterval = 24.hours

    // MARK: - Podcast functions

    func podcastUpdated(podcastUuid: String) {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastUpdated, object: podcastUuid)
    }

    func podcastAdded(podcastUuid: String) {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastAdded, object: podcastUuid)
    }

    func checkForUnusedPodcasts() {
        Task {
            await PodcastManager.shared.checkForUnusedPodcasts()
        }
    }

    func applyAutoArchivingToAllPodcasts() {
        PodcastManager.shared.applyAutoArchivingToAllPodcasts()
    }

    // MARK: - Playlists

    func playlistChanged() {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.playlistChanged)
    }

    // MARK: - Episode functions

    func episodeStarredChanged(episode: Episode) {
        if PlaybackManager.shared.isCurrentEpisode(uuid: episode.uuid) {
            PlaybackManager.shared.nowPlayingStarredChanged()
        }
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeStarredChanged, object: episode.uuid)
    }

    func archiveEpisodeExternal(episode: Episode) {
        EpisodeManager.archiveEpisodeExternal(episode)
    }

    func markEpisodeAsPlayedExternal(episode: Episode) {
        EpisodeManager.markEpisodeAsPlayedExternal(episode)
    }

    func cleanupAllUnusedEpisodeBuffers() {
        EpisodeManager.cleanupAllUnusedEpisodeBuffers()
    }

    func episodeCanBeCleanedUp(episode: Episode) -> Bool {
        episode.episodeCanBeCleanedUp()
    }

    // User Episodes functions
    func deleteFromDevice(userEpisode: UserEpisode) {
        #if !APPCLIP
        UserEpisodeManager.deleteFromDevice(userEpisode: userEpisode)
        #endif
    }

    func performActionsAfterRefresh() {
        cleanupNetworkDataUsageIfNeeded()
        PodcastManager.shared.checkForPendingAndAutoDownloads()
        #if !APPCLIP
        PlaylistManager.checkForAutoDownloads()
        #endif
        DispatchQueue.main.async {
            PlaybackManager.shared.effectsChangedExternally()
            #if !os(tvOS)
            Theme.shared.toggleTheme()
            #endif
            #if !APPCLIP && !os(tvOS)
            NotificationsHelper.shared.register(checkToken: true)
            #endif
        }
    }

    private func cleanupNetworkDataUsageIfNeeded() {

        let defaults = UserDefaults.standard
        let lastCleanupDate = defaults.object(forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate) as? Date

        guard DateUtil.hasEnoughTimePassed(since: lastCleanupDate, time: Self.networkDataUsageCleanupInterval) else {
            return
        }

        let cleanupDate = Date()
        defaults.set(cleanupDate, forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate)

        Task {
            let didCleanup = await DataManager.shared.networkDataUsageManager.deleteRecords(
                olderThan: Date(timeIntervalSinceNow: -Self.networkDataUsageRetentionPeriod)
            )

            if !didCleanup {
                defaults.set(lastCleanupDate, forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate)
            }
        }
    }

    func userEpisodeFileProtocol() -> FilePathProtocol {
        DownloadManager.shared
    }

    // MARK: - Settings

    func isPushEnabled() -> Bool {
        #if APPCLIP || os(tvOS)
        false
        #else
        NotificationsHelper.shared.pushEnabled()
        #endif
    }

    func isNewEpisodeNotificationsEnabled() -> Bool {
        #if APPCLIP || os(tvOS)
        false
        #else
        Settings.notificationsNewEpisodes
        #endif
    }

    func defaultPodcastGrouping() -> Int32 {
        Settings.defaultPodcastGrouping.rawValue
    }

    func defaultShowArchived() -> Bool {
        Settings.showArchivedDefault
    }

    func uniqueAppId() -> String {
        UserDefaults.standard.string(forKey: Constants.UserDefaults.appId) ?? ""
    }

    func appVersion() -> String {
        Settings.appVersion()
    }

    func privateUserAgent() -> String {
        "Pocket Casts/iOS/" + Settings.appVersion()
    }

    func autoDownloadLatestEpisodes(uuids: [String]) {
        if Settings.autoDownloadEnabled() {
            if Settings.autoDownloadMobileDataAllowed() || NetworkUtils.shared.isConnectedToUnexpensiveConnection() {
                for uuid in uuids {
                    DownloadManager.shared.addToQueue(episodeUuid: uuid)
                }
            }
        }
    }

    func minTimeBetweenProgressSaves() -> Double {
        Settings.minTimeBetweenProgressSaves()
    }

    func production() -> Bool {
        #if STAGING
        return false
        #else
        return true
        #endif
    }
}
