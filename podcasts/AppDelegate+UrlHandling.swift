import CoreServices
import Foundation
import JLRoutes
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import UniformTypeIdentifiers

extension AppDelegate {
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        appDelegate()?.handleShortcutItem(shortcutItem)
    }

    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if let urlString = shortcutItem.userInfo?["url"] as? String, let url = URL(string: urlString) {
            JLRoutes.routeURL(url)
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let progressViewController = SceneHelper.rootViewController() else { return false }
        return handleOpenUrl(url: url, rootViewController: progressViewController)
    }

    func handleOpenUrl(url: URL, rootViewController: UIViewController) -> Bool {
        if url.isFileURL {
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }

            let supportedTypes: [UTType] = [.xml, UTType("public.opml"), UTType("unofficial.opml")].compactMap { $0 }

            let isSupported = supportedTypes.contains { supportedType in
                type.conforms(to: supportedType)
            }

            if let fileExtension = UTType.pcasts.preferredFilenameExtension, type.conforms(to: UTType(filenameExtension: fileExtension)!) {
                let alert = UIAlertController(title: L10n.pcastsImportTitle, message: L10n.pcastsImportMessage, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.import, style: .destructive) { _ in
                    Task {
                        do {
                            let fileWrapper = try FileWrapper(url: url)
                            try PCBundleDoc.performImport(from: fileWrapper)
                        } catch {
                            FileLog.shared.addMessage("File Import failed with error \(error)")
                        }
                    }
                })
                alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
                rootViewController.present(alert, animated: true)
            }

            if isSupported {
                progressDialog = ShiftyLoadingAlert(title: L10n.opmlImporting)
                rootViewController.dismiss(animated: false, completion: nil)
                progressDialog?.showAlert(rootViewController, hasProgress: false, completion: { [weak self] in
                    if let progressDialog = self?.progressDialog {
                        PodcastManager.shared.importPodcastsFromOpml(url, progressWindow: progressDialog)
                    }
                })
            } else if type.conforms(to: .audio) || type.conforms(to: .movie) {
                NavigationManager.shared.navigateTo(NavigationManager.uploadedPageKey, data: [NavigationManager.uploadFileKey: url])
            }
        } else {
            // check to see what the scheme is we support itpc, http, feed & our own pktc
            if let scheme = url.scheme, scheme == "pktc" {
                JLRoutes.routeURL(url)
            }
        }
        return true
    }

    func setupRoutes() {
        // 3D touch shortcuts
        JLRoutes.global().addRoute("/shortcuts/:shortcut") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let shortcut = parameters["shortcut"] as? String else { return false }

            if shortcut == "pause" {
                PlaybackManager.shared.pause()
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else if shortcut == "play" {
                PlaybackManager.shared.play()
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else if shortcut == "markAsPlayed" {
                if let episode = PlaybackManager.shared.currentEpisode {
                    EpisodeManager.markAsPlayed(episode: episode, fireNotification: true)
                }
            } else if shortcut == "discover" {
                NavigationManager.shared.navigateTo(NavigationManager.discoverPageKey, data: nil)
            }

            return true
        }

        // open a playlist from a shortcut
        JLRoutes.global().addRoute("/shortcuts/filter/:filterId") { parameters -> Bool in
            guard let playlistId = parameters["filterId"] as? String, let playlist = DataManager.shared.findPlaylist(uuid: playlistId) else { return false }

            NavigationManager.shared.navigateTo(NavigationManager.filterPageKey, data: [NavigationManager.filterUuidKey: playlist.uuid])

            return true
        }

        // open a podcast from a shortcut
        JLRoutes.global().addRoute("/shortcuts/podcast/:podcastUuid") { parameters -> Bool in
            guard let podcastUuid = parameters["podcastUuid"] as? String, let podcast = DataManager.shared.findPodcast(uuid: podcastUuid) else { return false }

            NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: podcast])

            return true
        }

        // share list page opened
        JLRoutes.global().addRoute("/sharelist/*") { parameters -> Bool in
            guard let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String] else { return false }

            let sharePath = pathComponents.joined(separator: "/")

            let jsonFileLocation = "http://\(sharePath).json"
            let listController = IncomingShareListViewController(jsonLocation: jsonFileLocation)
            let navController = SJUIUtils.popupNavController(for: listController)

            SceneHelper.rootViewController()?.present(navController, animated: true, completion: nil)

            return true
        }

        // URL schemes for open, play, pause
        JLRoutes.global().addRoute("/open") { _ -> Bool in
            true
        }
        JLRoutes.global().addRoute("/play") { _ -> Bool in
            PlaybackManager.shared.play()

            return true
        }
        JLRoutes.global().addRoute("/pause") { _ -> Bool in
            PlaybackManager.shared.pause()

            return true
        }

        // Open to discover
        JLRoutes.global().addRoute("/discover/*") { paramDict -> Bool in

            var data: NSDictionary?
            if let pathComponents = paramDict[JLRouteWildcardComponentsKey] as? [String], let itemID = pathComponents.first {
                data = [NavigationManager.discoverListKey: itemID]
            }
            NavigationManager.shared.navigateTo(NavigationManager.discoverPageKey, data: data)

            return true
        }

        // Support for subscribing to a feed URL
        JLRoutes.global().addRoute("/subscribe/*") { [weak self] parameters -> Bool in
            guard
                let strongSelf = self,
                let rootController = SceneHelper.rootViewController(includeTopMost: false), //I don't want to consider the top most presented but the main root instead
                let subscribeUrl = (parameters[JLRouteURLKey] as? URL)?.absoluteString
            else {
                return false
            }

            let prefix = "pktc://subscribe/"
            if prefix.count >= subscribeUrl.count { return true } // this request is missing a URL

            let feedUrl = subscribeUrl.replacingOccurrences(of: prefix, with: "")

            let searchTerm = !feedUrl.hasPrefix("http://") && !feedUrl.hasPrefix("https://") ? "http://\(feedUrl)" : feedUrl

            strongSelf.progressDialog = ShiftyLoadingAlert(title: L10n.podcastLoading)
            rootController.dismiss(animated: false, completion: nil)
            strongSelf.progressDialog?.showAlert(rootController, hasProgress: false, completion: {
                MainServerHandler.shared.podcastSearch(searchTerm: searchTerm) { response in
                    guard let uuid = response?.result?.podcast?.uuid else {
                        DispatchQueue.main.async {
                            self?.hideProgressDialog()

                            SJUIUtils.showAlert(title: L10n.error, message: L10n.errorGeneralPodcastNotFound, from: SceneHelper.rootViewController())
                        }

                        return
                    }
                    ServerPodcastManager.shared.addFromUuidWithRetries(podcastUuid: uuid, subscribe: false) { success in
                        DispatchQueue.main.async {
                            self?.hideProgressDialog()

                            if success {
                                NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: uuid])
                            } else {
                                SJUIUtils.showAlert(title: L10n.error, message: L10n.errorGeneralPodcastNotFound, from: SceneHelper.rootViewController())
                            }
                        }
                    }
                }
            })

            return true
        }

        // Today Centre Widget thingy
        JLRoutes.global().addRoute("/widget/*") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String], let episodeUuid = pathComponents[safe: 0] else { return false }

            guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return true }

            strongSelf.openPlayerWhenReadyFromExternalEvent()

            if PlaybackManager.shared.isCurrentEpisode(uuid: episode.uuid) {
                if !PlaybackManager.shared.isPlaying {
                    PlaybackManager.shared.play()
                }
            } else {
                PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
            }

            return true
        }

        // Home screen Widget
        JLRoutes.global().addRoute("/widget-episode/*") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String], let episodeUuid = pathComponents[safe: 0] else { return false }

            guard let baseEpisode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else { return true }

            if PlaybackManager.shared.isCurrentEpisode(uuid: baseEpisode.uuid) {
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else {
                if let episode = baseEpisode as? Episode {
                    NavigationManager.shared.navigateTo(NavigationManager.episodePageKey, data: [NavigationManager.episodeUuidKey: episode.uuid])
                } else if baseEpisode is UserEpisode {
                    NavigationManager.shared.navigateTo(NavigationManager.filesPageKey, data: nil)
                }
            }
            return true
        }

        JLRoutes.global().addRoute("/last_opened/*") { _ in
            return true
        }

        JLRoutes.global().addRoute("/show_player") { [weak self] _ -> Bool in
            self?.openPlayerWhenReadyFromExternalEvent()
            return true
        }

        JLRoutes.global().addRoute("social/share/:showOrPrivate/:sharingId") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let folder = parameters["showOrPrivate"] as? String, let sharingId = parameters["sharingId"] as? String, let controller = SceneHelper.rootViewController() else { return false }
            var sharePath = "social/share/\(folder)/\(sharingId)"
            if let timestamp = parameters["t"] as? String {
                sharePath = sharePath + "/?t=\(timestamp)"
            }
            FileLog.shared.addMessage("Opening share link, path: \(folder)/\(sharingId)")
            strongSelf.openSharePath(sharePath, controller: controller, onErrorOpen: nil)
            return true
        }

        JLRoutes.global().addRoute("/upnext/*") { [weak self] paramDict -> Bool in
            var source: UpNextViewSource = .unknown
            var showFromMiniPlayer: Bool = true
            if let location = paramDict["location"] as? String, location == "tab" {
                showFromMiniPlayer = false
            }
            if let sourceString = paramDict["source"] as? String {
                source = UpNextViewSource(rawValue: sourceString) ?? .unknown
            }
            if showFromMiniPlayer {
                self?.miniPlayer()?.showUpNext(from: source)
            } else {
                NavigationManager.shared.navigateTo(NavigationManager.upNextPageKey)
            }

            return true
        }

        // Import OMPL extension
        JLRoutes.global().addRoute("/import-file/*") { [weak self] parameters -> Bool in
            guard let self,
                  let rootViewController = SceneHelper.rootViewController(),
                  let originalUrl = parameters[JLRouteURLKey] as? URL else { return false }

            let fileURLString = originalUrl.absoluteString.replacingOccurrences(of: "pktc://import-file/", with: "")

            guard let fileURL = URL(string: fileURLString) else {
                return true
            }

            return self.handleOpenUrl(url: fileURL, rootViewController: rootViewController)
        }
    }

    func openSharePath(_ path: String, controller: UIViewController, onErrorOpen: URL?) {
        progressDialog = ShiftyLoadingAlert(title: L10n.sharedItemLoading)
        progressDialog?.showAlert(controller, hasProgress: false) {
            // Parse the URL into path and query components so that any query parameters
            // (e.g. ?t=123) do not interfere with UUID extraction.
            let urlComponents = URLComponents(string: path)
            let cleanPath = urlComponents?.path.isEmpty == false ? urlComponents!.path : path
            let timestamp: Double? = {
                guard let queryItems = urlComponents?.queryItems else { return nil }
                guard let tItem = queryItems.first(where: { $0.name == "t" }) else { return nil }
                guard let value = tItem.value, let doubleValue = Double(value) else { return nil }
                return doubleValue
            }()

            // URLs that are already in the format https://pca.st/podcast/da3271a0-69e7-0132-d9fd-5f4c86fd3263 (or /private/) have the podcast UUID in them already so no need to ask the refresh server for it
            // Also handles new format: /podcast/{podcastSlug}/{podcastUuid}/{episodeSlug}/{episodeUuid}
            if cleanPath.contains("/podcast/") || cleanPath.contains("/private/") {
                // Check for new format with episode: /podcast/{slug}/{podcastUuid}/{episodeSlug}/{episodeUuid}
                if let podcastRange = cleanPath.range(of: "/podcast/") ?? cleanPath.range(of: "/private/") {
                    let afterPodcast = String(cleanPath[podcastRange.upperBound...])
                    let components = afterPodcast.split(separator: "/").map(String.init)

                    // New format: 4 components = podcastSlug, podcastUuid, episodeSlug, episodeUuid
                    if components.count == 4 {
                        let podcastUuid = components[1]
                        let episodeUuid = components[3]
                        self.loadAndShowEpisode(episodeUuid: episodeUuid, podcastUuid: podcastUuid, timestamp: timestamp)
                        return
                    }
                }

                // Original format: just podcast UUID as last component
                if let lastSlashIndex = cleanPath.lastIndex(of: "/") {
                    let startIndex = cleanPath.index(lastSlashIndex, offsetBy: 1)
                    let uuid = cleanPath.suffix(from: startIndex)
                    let podcastHeader = PodcastHeader(uuid: String(uuid))
                    DispatchQueue.main.async {
                        self.hideProgressDialog()
                        NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: podcastHeader])
                    }

                    return
                }
            }

            PodcastManager.shared.importSharedItemFromUrl(path) { item in
                guard let item else {
                    self.hideProgressDialog()
                    FileLog.shared.addMessage("Unable to load shared item \(path)")
                    if let onErrorOpen {
                        UIApplication.shared.open(onErrorOpen, options: [:], completionHandler: nil)
                    }

                    return
                }

                if item.isPodcastOnly() {
                    guard let podcastHeader = item.podcastHeader else {
                        self.hideProgressDialog()

                        return
                    }

                    DispatchQueue.main.async {
                        self.hideProgressDialog()
                        NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: podcastHeader])
                    }
                } else if let episodeUuid = item.episodeHeader?.uuid, let podcastUuid = item.podcastHeader?.uuid {
                    let timestamp = item.fromTime?.toDouble()
                    self.loadAndShowEpisode(episodeUuid: episodeUuid, podcastUuid: podcastUuid, timestamp: timestamp)
                }
            }
        }
    }

    private func loadAndShowEpisode(episodeUuid: String, podcastUuid: String, timestamp: TimeInterval? = nil) {
        if let podcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) {
            // if we're subscribed to the podcast, we'll likely have this episode, just open it
            if podcast.isSubscribed() {
                openEpisode(episodeUuid, from: podcast, timestamp: timestamp)
            } else { // if we're not subscribed, than it's possible our local copy is out of date, so we'll need to update it first
                ServerPodcastManager.shared.updatePodcastIfRequired(podcast: podcast) { _ in
                    self.openEpisode(episodeUuid, from: podcast, timestamp: timestamp)
                }
            }

            return
        }

        ServerPodcastManager.shared.addFromUuid(podcastUuid: podcastUuid, subscribe: false, completion: { success in
            if success, let podcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) {
                self.openEpisode(episodeUuid, from: podcast, timestamp: timestamp)
            } else {
                DispatchQueue.main.async {
                    self.hideProgressDialog()
                    SJUIUtils.showAlert(title: L10n.podcastShareErrorTitle, message: L10n.podcastShareErrorMsg, from: SceneHelper.rootViewController())
                }
            }
        })
    }
}
