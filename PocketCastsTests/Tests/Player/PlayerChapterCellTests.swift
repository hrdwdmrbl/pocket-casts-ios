import UIKit
import XCTest

@testable import podcasts

@MainActor
final class PlayerChapterCellTests: XCTestCase {
    func testChapterRowsLoadAndDisplayAcrossPlaybackStates() throws {
        let cell = try XCTUnwrap(UINib(nibName: "PlayerChapterCell", bundle: Bundle(for: PlayerChapterCell.self))
            .instantiate(withOwner: nil).first as? PlayerChapterCell)
        cell.frame = CGRect(x: 0, y: 0, width: 375, height: 80)

        let chapter = ChapterInfo()
        chapter.title = "An episode chapter"
        chapter.duration = 120
        chapter.index = 0

        for state: PlayerChapterCell.ChapterPlayState in [.played, .currentlyPlaying, .currentlyPaused, .future] {
            cell.populateFrom(chapter: chapter, playState: state, linkTapped: { _ in })
            cell.layoutIfNeeded()

            XCTAssertEqual(cell.chapterName.text, chapter.title)
            XCTAssertEqual(cell.chapterNumber.text, "1")
            XCTAssertFalse(cell.chapterName.hasAmbiguousLayout)
            XCTAssertFalse(cell.chapterNumber.hasAmbiguousLayout)
            XCTAssertTrue(cell.contentView.bounds.contains(cell.chapterName.frame))
            XCTAssertGreaterThan(cell.chapterName.bounds.width, 0)
        }
    }
}
