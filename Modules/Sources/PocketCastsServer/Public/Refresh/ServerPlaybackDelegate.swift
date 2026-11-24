import PocketCastsDataModel

public protocol ServerPlaybackDelegate {
    func isActivelyPlaying(episodeUuid: String) -> Bool
    func inUpNext(episode: BaseEpisode?) -> Bool
    func addToUpNext(episode: BaseEpisode, ignoringQueueLimit: Bool, toTop: Bool)
    func removeLastEpisodeFromUpNext()
    func upNextQueueCount() -> Int
}
