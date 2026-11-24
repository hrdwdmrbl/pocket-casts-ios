import Foundation
import PocketCastsDataModel
import PocketCastsServer

extension PodcastManager {
    func unsubscribe(podcast: Podcast) {
        for episode in dataManager.allEpisodes(forPodcastId: podcast.id) {
            EpisodeManager.deleteDownloadedFiles(episode: episode)
        }

        podcast.subscribed = 0
        podcast.autoArchiveEpisodeLimit = 0
        podcast.autoDownloadSetting = AutoDownloadSetting.off.rawValue
        podcast.pushEnabled = false
        podcast.autoAddToUpNext = AutoAddToUpNextSetting.off.rawValue
        dataManager.save(podcast: podcast)

        PlaylistManager.handlePodcastUnsubscribed(podcastUuid: podcast.uuid)
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastDeleted, object: podcast.uuid)
    }
}
