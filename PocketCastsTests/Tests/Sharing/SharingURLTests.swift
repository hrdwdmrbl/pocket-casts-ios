import AEXML
import Combine
import PocketCastsDataModel
import SwiftUI
import XCTest

@testable import podcasts

@MainActor
final class SharingURLTests: XCTestCase {
    private let audioURL = "https://podcasta.example/media/episode.mp3?token=a%2Fb%2Bc%3D&download=1"

    func testCopyEpisodeLinkUsesProcessedAudioURLUnchanged() async throws {
        let episode = Episode()
        episode.uuid = "episode-uuid"
        episode.downloadUrl = audioURL

        try await ShareDestination.copyLink.share(.episode(episode), style: .large,
                                                   clipTime: ClipTime(start: 0, end: 30), clipUUID: "clip",
                                                   progress: .constant(nil), presentFrom: CurrentValueSubject(.zero))

        XCTAssertEqual(UIPasteboard.general.string, audioURL)
    }

    func testTimestampLinksPreserveAudioAccessTokenAndClipPrecision() async throws {
        let episode = Episode()
        episode.downloadUrl = audioURL
        let options: [(SharingModal.Option, String)] = [
            (.currentPosition(episode, 3723), "t=3723.0"),
            (.clip(episode, 3723), "t=3723.0"),
            (.clipShare(episode, ClipTime(start: 3723.125, end: 3753.875), .audio), "t=3723.125,3753.875")
        ]

        for (option, fragment) in options {
            let url = try await option.shareURL
            XCTAssertEqual(url.absoluteString, audioURL + "#" + fragment)
        }
    }

    func testOPMLPreservesPrivateFeedURLsAndEscapesTitlesAndTokens() throws {
        let podcast = Podcast()
        podcast.uuid = "private-podcast"
        podcast.title = "Research & Development <Weekly>"
        podcast.isPrivate = true
        podcast.podcastUrl = "https://publisher.example/website"
        let feedURL = try XCTUnwrap(URL(string: "https://podcasta.example/feeds/private/rss?token=a%2Fb&key=123"))
        let exporter = OpmlExporter(podcasts: [podcast])

        let xml = exporter.document(feedURLs: [podcast.uuid: feedURL]).xmlString
        let parsed = try AEXMLDocument(xmlData: Data(xml.utf8))
        let feeds = parsed.root["body"]["outline"].children

        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.attributes["text"], podcast.title)
        XCTAssertEqual(feeds.first?.attributes["xmlUrl"], feedURL.absoluteString)
    }
}
