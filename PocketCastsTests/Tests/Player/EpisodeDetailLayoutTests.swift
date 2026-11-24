import PocketCastsDataModel
import UIKit
import XCTest

@testable import podcasts

@MainActor
final class EpisodeDetailLayoutTests: XCTestCase {
    func testOpeningAnEpisodeShowsItsTitleAndTappablePlayButton() throws {
        let podcast = Podcast()
        podcast.uuid = "episode-layout-podcast"
        podcast.title = "Test Podcast"
        let episode = Episode()
        episode.uuid = "episode-layout-episode"
        episode.podcastUuid = podcast.uuid
        episode.title = "Test Episode"
        episode.duration = 3600

        let controller = EpisodeDetailViewController(episode: episode, podcast: podcast, source: .podcastScreen)
        controller.loadViewIfNeeded()
        controller.updateDisplayedData(reloadingEpisode: false)

        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 768, height: 1024)] {
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.layoutIfNeeded()

            XCTAssertEqual(controller.mainScrollView.bounds.size, size)
            XCTAssertEqual(controller.episodeName.text, episode.title)
            let titleFrame = controller.episodeName.convert(controller.episodeName.bounds, to: controller.view)
            XCTAssertTrue(controller.view.bounds.contains(titleFrame))

            let button = try XCTUnwrap(controller.playPauseBtn)
            let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: controller.view)
            let hit = try XCTUnwrap(controller.view.hitTest(center, with: nil))
            XCTAssertTrue(hit.isDescendant(of: button), "The episode's Play button must be visible and receive taps at \(size)")
        }
    }
}
