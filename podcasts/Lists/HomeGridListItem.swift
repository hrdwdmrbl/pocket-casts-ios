import DifferenceKit
import Foundation
import PocketCastsDataModel
import PocketCastsServer

class HomeGridListItem: ListItem {
    let gridItem: HomeGridItem?

    var podcast: Podcast? {
        gridItem?.podcast
    }

    let theme: Theme.ThemeType
    let badgeType: BadgeType
    var frozenBadgeCount = -1 // used for comparisons only

    init(gridItem: HomeGridItem?, badgeType: BadgeType, theme: Theme.ThemeType) {
        self.gridItem = gridItem
        self.badgeType = badgeType
        self.theme = theme

        super.init()
    }

    static let empty = HomeGridListItem(gridItem: nil, badgeType: .off, theme: Theme.shared.activeTheme)

    override var differenceIdentifier: String {
        if let podcast {
            return "podcast-\(podcast.uuid)"
        }
        return "empty"
    }

    var isEmpty: Bool {
        gridItem == nil
    }

    static func == (lhs: HomeGridListItem, rhs: HomeGridListItem) -> Bool {
        lhs.handleIsEqual(rhs)
    }

    override func handleIsEqual(_ otherItem: ListItem) -> Bool {
        guard let rhs = otherItem as? HomeGridListItem else { return false }

        if let otherPodcast = rhs.podcast, let podcast {
            return differenceIdentifier == rhs.differenceIdentifier &&
                frozenBadgeCount == rhs.frozenBadgeCount &&
                badgeType == rhs.badgeType &&
                podcast.startFrom == otherPodcast.startFrom &&
                podcast.autoDownloadSetting == otherPodcast.autoDownloadSetting &&
                podcast.overrideGlobalArchive == otherPodcast.overrideGlobalArchive &&
                podcast.autoArchiveInactiveAfter == otherPodcast.autoArchiveInactiveAfter &&
                podcast.autoArchivePlayedAfter == otherPodcast.autoArchivePlayedAfter &&
                podcast.subscribed == otherPodcast.subscribed &&
                podcast.episodeGrouping == otherPodcast.episodeGrouping &&
                podcast.playbackSpeed == otherPodcast.playbackSpeed &&
                podcast.boostVolume == otherPodcast.boostVolume &&
                podcast.trimSilenceAmount == otherPodcast.trimSilenceAmount &&
                podcast.settings == otherPodcast.settings
        }

        return false
    }
}
