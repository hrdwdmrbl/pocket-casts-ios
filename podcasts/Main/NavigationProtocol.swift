import Foundation
import PocketCastsDataModel
import PocketCastsServer
import UIKit

protocol NavigationProtocol: AnyObject {
    func navigateToPodcastList(_ animated: Bool)
    func navigateToPodcast(_ podcast: Podcast, source: PodcastScreenSource)
    func navigateToPodcastInfo(_ podcastInfo: PodcastInfo, source: PodcastScreenSource)
    func navigateTo(podcast searchResult: PodcastSearchResult, source: PodcastScreenSource)

    func navigateToEpisode(_ episodeUuid: String, podcastUuid: String?, timestamp: TimeInterval?)

    func navigateToDiscover(_ animated: Bool)
    func navigateToDiscover(category: String, animated: Bool)
    func navigateToDiscover(listID: String, animated: Bool)
    func navigateToDiscoverNetworks(_ animated: Bool)

    func navigateToSettings(row: SettingsViewController.TableRow?, animated: Bool)

    func navigateToFilter(_ filter: EpisodeFilter?, animated: Bool)
    func navigateToAddFilter()
    func presentManualPlaylistsChooser(for episode: Episode, rootViewController: UIViewController?, source: String)

    func navigateToUpNext(_ animated: Bool)

    func navigateToFiles()
    func navigateToAddCustom(_ fileURL: URL)
    func showSettings(row: SettingsViewController.TableRow?)
    func showSettingsAppearance(showThemeSelection: Bool)
    func showHeadphoneSettings()
    func showGeneralSettings(row: GeneralSettingsViewController.TableRow?)
    func showTermsOfUse()
    func showPrivacyPolicy()

    func showInSafariViewController(urlString: String)
    func dismissPresentedViewController(completion: (() -> Void)?)
}
