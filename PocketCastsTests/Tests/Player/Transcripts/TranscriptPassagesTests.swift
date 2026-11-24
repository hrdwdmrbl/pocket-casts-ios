import XCTest
@testable import podcasts

final class TranscriptPassagesTests: XCTestCase {
    func testTimedSearchPassagesPreserveSpeakersAndMatchAcrossCaptionBoundaries() throws {
        let model = try XCTUnwrap(TranscriptModel.makeModel(from: """
            WEBVTT

            00:00:01.000 --> 00:00:03.000
            <v Alex>We discussed nuclear

            00:00:03.000 --> 00:00:06.000
            <v Alex>power today.

            00:00:07.000 --> 00:00:09.000
            <v Sam>What about solar?

            00:02:00.000 --> 00:02:03.000
            <v Sam>Another topic.
            """, format: .vtt))
        let passages = model.searchPassages(episodeUuid: "episode")
        XCTAssertEqual(passages.count, 3)
        XCTAssertTrue(passages[0].text.contains("nuclear power"))
        XCTAssertEqual(passages[0].speaker, "Alex")
        XCTAssertEqual(passages[0].startTime, 1)
        XCTAssertEqual(passages[0].endTime, 6)
        XCTAssertEqual(passages[1].speaker, "Sam")
        XCTAssertEqual(passages[2].startTime, 120)
    }

    func testUntimedTranscriptRetainsAllWordsWithoutInventingSpeakerOrTiming() throws {
        let text = Array(repeating: "Café 👋", count: 200).joined(separator: " ")
        let model = try XCTUnwrap(TranscriptModel.makeModel(from: text, format: .textPlain))
        let passages = model.searchPassages(episodeUuid: "episode")
        XCTAssertEqual(passages.map(\.text).joined(separator: " "), text)
        XCTAssertTrue(passages.allSatisfy { $0.startTime == nil && $0.endTime == nil && $0.speaker == nil })
        XCTAssertEqual(Set(passages.map(\.id)).count, passages.count)
    }
}
