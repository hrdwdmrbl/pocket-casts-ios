import PocketCastsDataModel

struct HomeGridItem: Identifiable {
    let podcast: Podcast

    var id: String { podcast.uuid }
}
