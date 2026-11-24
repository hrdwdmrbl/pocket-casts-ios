import PocketCastsDataModel
import PocketCastsServer
import UIKit

class PodcastSearchCell: ThemeableCell {
    @IBOutlet var podcastImage: PodcastImageView!

    @IBOutlet var podcastName: ThemeableLabel!
    @IBOutlet var podcastAuthor: ThemeableLabel! {
        didSet {
            podcastAuthor.style = .primaryText02
        }
    }

    @IBOutlet var subscribedIcon: UIImageView!

    func populateFrom(podcast: Podcast) {
        podcastName.text = podcast.title
        podcastAuthor.text = podcast.author

        podcastImage.setPodcast(uuid: podcast.uuid, size: .list)
        podcastImage.isHidden = false
        subscribedIcon.isHidden = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func handleThemeDidChange() {
        subscribedIcon.image = UIImage(named: "discover_tick")?.tintedImage(ThemeColor.support02())
    }
}
