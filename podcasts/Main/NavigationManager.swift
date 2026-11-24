import PocketCastsDataModel
import PocketCastsServer
import UIKit
import PocketCastsUtils

class NavigationManager {
    static let podcastPageKey = "podcastPage"
    static let podcastKey = "podcast"
    /// Optional `PodcastScreenSource` saying where the podcast page is being opened from
    static let podcastSourceKey = "podcastSource"
    static let popToRootViewController = "popToRootViewController"

    static let episodePageKey = "episodePage"
    static let episodeUuidKey = "episode"
    static let episodeTimestamp = "episodeTimestamp"

    static let podcastListPageKey = "podcastList"
    static let discoverPageKey = "discoverPage"
    static let discoverCategoryKey = "discoverCategory"
    static let discoverListKey = "discoverList"
    static let discoverNetworksPageKey = "discoverNetworksPage"

    static let filterPageKey = "filterPage"
    static let filterUuidKey = "filterUuid"

    static let filterAddKey = "filterPageAdd"

    static let uploadedPageKey = "uploadedPage"
    static let uploadFileKey = "uploadFile"

    static let filesPageKey = "filesPage"

    static let showPrivacyPolicyPageKey = "showPrivacyPage"
    static let showTermsOfUsePageKey = "showTermsOfUsePage"

    static let openUrlInSafariVCKey = "openSafariVCUrlPage"
    static let safariVCUrlKey = "safariVCUrlKey"

    static let settingsPageKey = "settingsPage"
    static let settingsRowKey = "settingsRow"
    static let settingsAppearanceKey = "appearancePage"
    static let settingsAppearanceShowThemeKey = "appearanceShowThemeKey"
    static let settingsRootKey = "profilePage"
    static let settingsItemKey = "profileRow"
    static let settingsRowDownloadsKey = "downloads"
    static let settingsHeadphoneKey = "headphoneSettings"

    static let settingsGeneralKey = "generalSettingsPage"
    static let settingsGeneralRowKey = "generalSettingsRow"

    static let upNextPageKey = "upNextPage"

    static let manualPlaylistsChooserKey = "manualPlaylistsChooserKey"
    static let manualPlaylistsChooserEpisodeKey = "manualPlaylistsChooserEpisodeKey"
    static let manualPlaylistsChooserRootKey = "manualPlaylistsChooserRootKey"
    static let manualPlaylistsChooserSourceKey = "manualPlaylistsChooserSourceKey"

    static let shared = NavigationManager()

    private weak var mainController: NavigationProtocol?
    var dimmingView: UIView?
    var miniPlayer: MiniPlayerViewController?

    private var lastNavKey = ""
    private var lastNavData: NSDictionary?

    // MARK: - Navigation

    func navigateTo(_ place: String, data: NSDictionary? = nil, animated: Bool = true) {
        performNavigation(place, data: data, animated: animated)
    }

    func mainViewControllerDidLoad(controller: NavigationProtocol) {
        mainController = controller
    }

    func dismissPresentedViewController(completion: (() -> Void)? = nil) {
        mainController?.dismissPresentedViewController(completion: completion)
    }

    private func performNavigation(_ place: String, data: NSDictionary?, animated: Bool) {
        lastNavKey = place
        lastNavData = data

        if place == NavigationManager.podcastPageKey {
            guard let data else { return }

            let source = data[NavigationManager.podcastSourceKey] as? PodcastScreenSource ?? .unknown

            if let podcast = data[NavigationManager.podcastKey] as? Podcast {
                mainController?.navigateToPodcast(podcast, source: source)
            }
            if let podcastUuid = data[NavigationManager.podcastKey] as? String {
                if let podcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) {
                    mainController?.navigateToPodcast(podcast, source: source)
                }
            } else if let podcastInfo = data[NavigationManager.podcastKey] as? PodcastInfo {
                mainController?.navigateToPodcastInfo(podcastInfo, source: source)
            } else if let podcastHeader = data[NavigationManager.podcastKey] as? PodcastHeader {
                // legacy PodcastHeader support
                var podcastInfo = PodcastInfo()
                podcastInfo.uuid = podcastHeader.uuid
                podcastInfo.title = podcastHeader.title
                podcastInfo.shortDescription = podcastHeader.headerDescription
                podcastInfo.author = podcastHeader.author
                podcastInfo.iTunesId = podcastHeader.itunesId?.intValue

                mainController?.navigateToPodcastInfo(podcastInfo, source: source)
            } else if let searchResult = data[NavigationManager.podcastKey] as? PodcastSearchResult {
                mainController?.navigateTo(podcast: searchResult, source: source)
            }
        } else if place == NavigationManager.episodePageKey {
            guard let data, let uuid = data[NavigationManager.episodeUuidKey] as? String else { return }

            mainController?.navigateToEpisode(uuid, podcastUuid: data[NavigationManager.podcastKey] as? String, timestamp: data[NavigationManager.episodeTimestamp] as? TimeInterval)
        } else if place == NavigationManager.podcastListPageKey {
            mainController?.navigateToPodcastList(animated)
        } else if place == NavigationManager.discoverPageKey {
            navigateToDiscover(data: data, animated: animated)
        } else if place == NavigationManager.discoverNetworksPageKey {
            mainController?.navigateToDiscoverNetworks(animated)
        } else if place == NavigationManager.filterPageKey {
            if let data, let filterUuid = data[NavigationManager.filterUuidKey] as? String, let filter = DataManager.shared.findPlaylist(uuid: filterUuid) {
                mainController?.navigateToFilter(filter, animated: animated)
            } else {
                mainController?.navigateToFilter(nil, animated: animated)
            }
        } else if place == NavigationManager.filterAddKey {
            mainController?.navigateToAddFilter()
        } else if place == NavigationManager.uploadedPageKey {
            if let data, let fileURL = data[NavigationManager.uploadFileKey] as? URL {
                mainController?.navigateToAddCustom(fileURL)
            }
        } else if place == NavigationManager.filesPageKey {
            mainController?.navigateToFiles()
        } else if place == NavigationManager.showPrivacyPolicyPageKey {
            mainController?.showPrivacyPolicy()
        } else if place == NavigationManager.showTermsOfUsePageKey {
            mainController?.showTermsOfUse()
        } else if place == NavigationManager.settingsAppearanceKey {
            var showThemeSelection = false
            if let data, let showThemeSelectionValue = data[NavigationManager.settingsAppearanceShowThemeKey] as? Bool {
                showThemeSelection = showThemeSelectionValue
            }
            mainController?.showSettingsAppearance(showThemeSelection: showThemeSelection)
        } else if place == NavigationManager.settingsRootKey {
            navigateToSettings(data: data, animated: animated)
        }
        else if place == NavigationManager.settingsHeadphoneKey {
            mainController?.showHeadphoneSettings()
        } else if place == NavigationManager.openUrlInSafariVCKey {
            if let data, let urlString = data[NavigationManager.safariVCUrlKey] as? String {
                mainController?.showInSafariViewController(urlString: urlString)
            }
        } else if place == NavigationManager.settingsGeneralKey {
            mainController?.showGeneralSettings(row: data?[NavigationManager.settingsGeneralRowKey] as? GeneralSettingsViewController.TableRow)
        } else if place == NavigationManager.upNextPageKey {
            mainController?.navigateToUpNext(true)
        } else if place == NavigationManager.settingsPageKey {
            let row = data?[NavigationManager.settingsRowKey] as? SettingsViewController.TableRow
            mainController?.showSettings(row: row)
        } else if place == NavigationManager.manualPlaylistsChooserKey {
            if let episode = data?[NavigationManager.manualPlaylistsChooserEpisodeKey] as? Episode {
                let root = data?[NavigationManager.manualPlaylistsChooserRootKey] as? UIViewController
                let source = data?[NavigationManager.manualPlaylistsChooserSourceKey] as? String ?? "swipe"
                mainController?.presentManualPlaylistsChooser(for: episode, rootViewController: root, source: source)
            }
        }
    }

    func navigateToDiscover(data: NSDictionary?, animated: Bool) {
        guard let data else {
            mainController?.navigateToDiscover(animated)
            return
        }

        if let category = data[NavigationManager.discoverCategoryKey] as? String {
            mainController?.navigateToDiscover(category: category, animated: animated)
            return
        }

        if let listId = data[NavigationManager.discoverListKey] as? String {
            mainController?.navigateToDiscover(listID: listId, animated: animated)
            return
        }
    }

    func navigateToSettings(data: NSDictionary?, animated: Bool) {
        guard let row = data?[NavigationManager.settingsItemKey] as? String else {
            mainController?.navigateToSettings(row: nil, animated: animated)
            return
        }
        if row == NavigationManager.settingsRowDownloadsKey {
            mainController?.navigateToSettings(row: .downloaded, animated: animated)
        }
    }
}
