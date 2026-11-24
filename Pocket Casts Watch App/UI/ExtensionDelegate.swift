
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    private var haveAttemptedStateRestore = false

    func applicationDidFinishLaunching() {

        SessionManager.shared.setup()
        restorePreviousStateIfRequired()
    }

    func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        restorePreviousStateIfRequired()
    }

    // indicates that the app was auto launched by watchOS because audio from the phone started playing. Isn't called when watchOS playback starts
    func handleRemoteNowPlayingActivity() {
        haveAttemptedStateRestore = true
        NavigationManager.shared.navigateToNowPlaying()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - State restoration

    private func restorePreviousStateIfRequired() {
        guard let lastPage = UserDefaults.standard.string(forKey: WatchConstants.UserDefaults.lastPage) else { return }

        let context = UserDefaults.standard.object(forKey: WatchConstants.UserDefaults.lastContext)
        if !haveAttemptedStateRestore {
            haveAttemptedStateRestore = true
            NavigationManager.shared.navigateToRestorable(name: lastPage, context: context)
        }
    }

    // MARK: - Background Refresh

}
