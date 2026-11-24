import PocketCastsDataModel
import UIKit
import PocketCastsUtils

@MainActor
class SharingHelper: NSObject {
    static let shared = SharingHelper()
    func shareLinkTo(podcast: Podcast, fromController: UIViewController, sourceRect: CGRect, sourceView: UIView) {

        SharingModal.show(option: .podcast(podcast), in: fromController)
    }

    func shareLinkTo(podcast: Podcast, fromController: UIViewController, barButtonItem: UIBarButtonItem?) {
        SharingModal.show(option: .podcast(podcast), in: fromController)
    }

    func shareLinkTo(episode: Episode, shareTime: TimeInterval, fromController: UIViewController, barButtonItem: UIBarButtonItem?) {
        let option: SharingModal.Option = shareTime == 0 ? .episode(episode) : .currentPosition(episode, shareTime)
        SharingModal.show(option: option, in: fromController)
    }

    func shareLinkTo(episode: Episode, shareTime: TimeInterval, fromController: UIViewController, sourceRect: CGRect, sourceView: UIView?, showArrow: Bool = true) {
        let option: SharingModal.Option = shareTime == 0 ? .episode(episode) : .currentPosition(episode, shareTime)
        SharingModal.show(option: option, in: fromController)
    }
}

extension Episode {
    var shareURL: URL {
        get throws {
            guard let downloadUrl, let url = URL(string: downloadUrl),
                  url.scheme == "https" || url.scheme == "http", url.host != nil else {
                throw URLError(.badURL)
            }
            return url
        }
    }
}
