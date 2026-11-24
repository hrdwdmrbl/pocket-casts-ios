import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class HomeGridDataHelper {
    var numberOfPodcasts: Int {
        DataManager.shared.podcastCount()
    }

    class func gridItems(orderedBy: LibrarySort) -> [HomeGridItem] {
        var podcasts = PodcastManager.shared.allPodcastsSorted(in: orderedBy)
        if orderedBy == .custom {
            podcasts.sort { $0.sortOrder < $1.sortOrder }
        }
        return podcasts.map { HomeGridItem(podcast: $0) }
    }

    #if !os(watchOS)
    class func gridListItems(orderedBy: LibrarySort, badgeType: BadgeType) -> [HomeGridListItem] {
        let items = gridItems(orderedBy: orderedBy).map {
            HomeGridListItem(gridItem: $0, badgeType: badgeType, theme: Theme.shared.activeTheme)
        }
        let unfinishedCounts = badgeType == .allUnplayed ? DataManager.shared.podcastUnfinishedCounts() : [:]
        for item in items {
            let podcast = item.gridItem!.podcast
            switch badgeType {
            case .allUnplayed:
                podcast.cachedUnreadCount = Int(unfinishedCounts[podcast.uuid] ?? 0)
            case .latestEpisode:
                let latestEpisode = DataManager.shared.findLatestEpisode(podcast: podcast)
                podcast.cachedUnreadCount = latestEpisode.map { $0.unplayed() && !$0.archived ? 1 : 0 } ?? 0
            default:
                continue
            }
            item.frozenBadgeCount = podcast.cachedUnreadCount
        }
        return items
    }
    #endif
}
