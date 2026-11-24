import AEXML
import Foundation
import PocketCastsDataModel
import PocketCastsServer

struct OpmlExporter {
    let podcasts: [Podcast]

    func export() async throws -> URL {
        let feedURLs = try await MainServerHandler.shared.exportPodcasts(uuids: podcasts.map(\.uuid))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("podcasts.opml")
        try document(feedURLs: feedURLs).xmlString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func document(feedURLs: [String: URL]) -> AEXMLDocument {
        let document = AEXMLDocument()
        let opml = document.addChild(name: "opml", attributes: ["version": "1.0"])
        let head = opml.addChild(name: "head")
        _ = head.addChild(name: "title", value: "Podcasta Feeds")

        let body = opml.addChild(name: "body")
        let outline = body.addChild(name: "outline", attributes: ["text": "feeds"])
        for podcast in podcasts {
            _ = outline.addChild(name: "outline", attributes: [
                "type": "rss",
                "text": podcast.title ?? "",
                "xmlUrl": feedURLs[podcast.uuid]!.absoluteString
            ])
        }
        return document
    }
}
