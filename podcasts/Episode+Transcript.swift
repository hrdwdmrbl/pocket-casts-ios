import Foundation
import PocketCastsDataModel
import PocketCastsUtils

extension Episode {
    func checkTranscriptAvailability() {
        Task {
            if let metadata = try? await ShowInfoCoordinator.shared.loadTranscriptsMetadata(podcastUuid: parentIdentifier(), episodeUuid: uuid) {
                let transcriptsAvailable = !metadata.isEmpty
                let userInfo = [
                    "episodeUuid": uuid,
                    "isAvailable": transcriptsAvailable,
                ]
                NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeTranscriptAvailabilityChanged, userInfo: userInfo)
            }
        }
    }
}
