import AVFoundation
import Foundation
import PocketCastsDataModel
import PocketCastsUtils

class EpisodeFileSizeUpdater {
    class func updateEpisodeDuration(episode: BaseEpisode) {
        let fileLocation = episode.pathToDownloadedFile(pathFinder: DownloadManager.shared)
        let url = URL(fileURLWithPath: fileLocation)
        let asset = AVURLAsset(url: url)

        Task {
            let duration: CMTime
            do {
                duration = try await asset.load(.duration)
            } catch {
                FileLog.shared.addMessage("EpisodeFileSizeUpdater: failed to load duration for episode \(episode.uuid): \(error)")
                return
            }

            let calculatedDuration = CMTimeGetSeconds(duration)
            guard calculatedDuration.isFinite else { return }
            if calculatedDuration < 10 || calculatedDuration > 36000 { return } // duration is too short or too long to be a podcast eg: less than 10 seconds or more than 10 hours

            let currentDuration = episode.duration
            if Int(currentDuration) == Int(calculatedDuration) { return } // we already have the correct duration

            DataManager.shared.saveEpisode(duration: calculatedDuration, episode: episode)
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeDurationChanged, object: episode.uuid)
        }
    }
}
