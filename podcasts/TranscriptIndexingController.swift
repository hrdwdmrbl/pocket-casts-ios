import PocketCastsServer
import UIKit

@MainActor
final class TranscriptIndexingController: NSObject {
    private var task: Task<Void, Never>?

    func start() {
        let center = NotificationCenter.default
        center.removeObserver(self)
        for notification in [ServerNotifications.podcastsRefreshed, Constants.Notifications.opmlImportCompleted] {
            center.addObserver(self, selector: #selector(libraryChanged), name: notification, object: nil)
        }
        let previous = task
        previous?.cancel()
        task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await TranscriptLibrary().indexLibrary()
        }
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        task?.cancel()
    }

    func stopAndWait() async {
        stop()
        await task?.value
        task = nil
    }

    @objc private func libraryChanged() {
        Task { @MainActor in
            if UIApplication.shared.applicationState == .active { start() }
        }
    }

    deinit {
        task?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}
