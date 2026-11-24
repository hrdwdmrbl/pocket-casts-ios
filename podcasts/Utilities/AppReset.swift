import Foundation
import Intents
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UserNotifications

enum AppReset {
    @MainActor
    static func reset() async throws {
        // Finish work that can write library data before clearing the database and files.
        Settings.setAutoDownloadEnabled(false)
        let importerQueue = PodcastManager.shared.importerQueue
        importerQueue.cancelAllOperations()
        await withCheckedContinuation { continuation in
            importerQueue.addBarrierBlock { continuation.resume() }
        }
        for task in await URLSession.shared.allTasks { task.cancel() }
        await ServerPodcastManager.shared.finishPendingSubscriptions()
        await RefreshManager.shared.cancelAllRefreshesAndWait()
        await DownloadManager.shared.cancelAllDownloads()
        await ShowInfoCoordinator.shared.clearCache()
        CacheServerHandler.shared.clearCache()
        DiscoverServerHandler.shared.discoveryCache.removeAllCachedResponses()
        await ImageManager.shared.clearAllImageCaches()

        try await Task.detached(priority: .userInitiated) {
            try deleteStoredData()
        }.value

        SearchHistoryModel.shared.removeAll()
        Settings.reset()
        StatsManager.shared.reset()
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
        try await INInteraction.deleteAll()
    }

    private static func deleteStoredData() throws {
        try DataManager.shared.deleteAllData()
        DataManager.shared.vacuumDatabase(minimumFreePageRatio: 0)
        URLCache.shared.removeAllCachedResponses()
        FileLog.shared.forceFlush()

        let fileManager = FileManager.default
        let directories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0],
            URL(fileURLWithPath: DownloadManager.shared.tempDownloadFolder),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
            fileManager.temporaryDirectory
        ]
        let databaseFiles = Set(DataManager.databaseFilePaths().map { URL(fileURLWithPath: $0).standardizedFileURL })
        for directory in directories {
            try deleteFiles(in: directory, keeping: databaseFiles)
        }
        let groupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.GroupUserDefaults.groupContainerId)!
        for file in try fileManager.contentsOfDirectory(at: groupDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        where file.lastPathComponent != "Library" {
            try fileManager.removeItem(at: file)
        }
    }

    /// Preserve the live database and directory structure used by the download and cache managers.
    static func deleteFiles(in directory: URL, keeping filesToKeep: Set<URL>) throws {
        let fileManager = FileManager.default
        for file in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
            if filesToKeep.contains(file.standardizedFileURL) { continue }
            let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isDirectory == true && values.isSymbolicLink != true {
                try deleteFiles(in: file, keeping: filesToKeep)
            } else {
                try fileManager.removeItem(at: file)
            }
        }
    }
}
