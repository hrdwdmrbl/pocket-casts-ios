import PocketCastsDataModel

public protocol ServerRefreshDelegate {
    func podcastAdded(podcastUuid: String)
    func checkForUnusedPodcasts()
    func applyAutoArchivingToAllPodcasts()
    func episodeCanBeCleanedUp(episode: Episode) -> Bool
    func autoDownloadLatestEpisodes(uuids: [String])
    func cleanupAllUnusedEpisodeBuffers()
    func performActionsAfterRefresh()
    func isPushEnabled() -> Bool
    func isNewEpisodeNotificationsEnabled() -> Bool
    func defaultPodcastGrouping() -> Int32
    func defaultShowArchived() -> Bool
    func uniqueAppId() -> String
    func appVersion() -> String
    func production() -> Bool
    func privateUserAgent() -> String
}
