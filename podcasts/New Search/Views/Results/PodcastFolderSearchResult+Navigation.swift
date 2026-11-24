import PocketCastsDataModel
import PocketCastsServer

extension PodcastSearchResult {
    func navigateTo() {
        switch kind {
        case .podcast:
            NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: self, NavigationManager.podcastSourceKey: PodcastScreenSource.search])
        }
    }
}
