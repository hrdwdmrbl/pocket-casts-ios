import UIKit
import UniformTypeIdentifiers
import XCTest

@MainActor
final class ShareFileImportTests: XCTestCase {
    private var sourceDirectory: URL!
    private var sharedDirectory: URL!
    private var originalOpml: Data?

    override func setUpWithError() throws {
        try super.setUpWithError()
        sourceDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        sharedDirectory = try XCTUnwrap(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.GroupUserDefaults.groupContainerId),
            "The share handoff tests require simulator code signing for app-group access."
        )
        let opml = sharedDirectory.appendingPathComponent("opml.opml")
        if FileManager.default.fileExists(atPath: opml.path) {
            originalOpml = try Data(contentsOf: opml)
        }
    }

    override func tearDownWithError() throws {
        if let sharedDirectory {
            let opml = sharedDirectory.appendingPathComponent("opml.opml")
            if let originalOpml {
                try originalOpml.write(to: opml)
            } else if FileManager.default.fileExists(atPath: opml.path) {
                try FileManager.default.removeItem(at: opml)
            }
        }
        if let sourceDirectory {
            try FileManager.default.removeItem(at: sourceDirectory)
        }
        try super.tearDownWithError()
    }

    func testSequentialOPMLImportsReadEachNewFileWhenAnOldImportAlreadyExists() async throws {
        let destination = sharedDirectory.appendingPathComponent("opml.opml")
        try opml(feed: "https://old.example/rss").write(to: destination)
        let source = sourceDirectory.appendingPathComponent("podcasts.opml")

        for feed in ["https://first.example/rss", "https://podcasta.example/feeds/second/rss"] {
            let contents = opml(feed: feed)
            try contents.write(to: source)
            let controller = makeController(provider: NSItemProvider(item: source as NSURL, typeIdentifier: UTType.data.identifier))
            let redirected = expectation(description: "Hand off newly shared OPML")
            controller.onRedirect = { redirected.fulfill() }

            controller.viewWillAppear(false)
            await fulfillment(of: [redirected], timeout: 5)
            let url = try XCTUnwrap(controller.redirectedURL)
            XCTAssertEqual(url, destination)
            XCTAssertEqual(try Data(contentsOf: url), contents)
            XCTAssertTrue(controller.context.completed)
            XCTAssertNil(controller.context.error)
        }
    }

    func testSequentialMediaImportsReplaceFilesWithTheSameName() async throws {
        let filename = UUID().uuidString + ".mp3"
        let source = sourceDirectory.appendingPathComponent(filename)
        let destination = sharedDirectory.appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at: destination) }

        for contents in [Data("first audio".utf8), Data("second audio".utf8)] {
            try contents.write(to: source)
            let controller = makeController(provider: NSItemProvider(item: source as NSURL, typeIdentifier: UTType.audio.identifier))
            let redirected = expectation(description: "Hand off newly shared audio")
            controller.onRedirect = { redirected.fulfill() }

            controller.viewWillAppear(false)
            await fulfillment(of: [redirected], timeout: 5)
            let url = try XCTUnwrap(controller.redirectedURL)
            XCTAssertEqual(url, destination)
            XCTAssertEqual(try Data(contentsOf: url), contents)
            XCTAssertTrue(controller.context.completed)
            XCTAssertNil(controller.context.error)
        }
    }

    func testCopyFailureCancelsInsteadOfOpeningTheOldOPML() async throws {
        try opml(feed: "https://old.example/rss").write(to: sharedDirectory.appendingPathComponent("opml.opml"))
        let missingFile = sourceDirectory.appendingPathComponent("missing.opml")
        let controller = makeController(provider: NSItemProvider(item: missingFile as NSURL, typeIdentifier: UTType.data.identifier))
        let cancelled = expectation(description: "Report copy failure")
        controller.context.onCancel = { error in
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
            cancelled.fulfill()
        }
        controller.onRedirect = { XCTFail("A failed copy must not start an import") }

        controller.viewWillAppear(false)
        await fulfillment(of: [cancelled], timeout: 5)
        XCTAssertFalse(controller.context.completed)
    }

    func testAttachmentLoadingFailureCancelsWithoutOpeningAnImport() async {
        let provider = NSItemProvider()
        let failure = NSError(domain: "ShareFileImportTests", code: 1)
        provider.registerItem(forTypeIdentifier: UTType.data.identifier) { completion, _, _ in
            completion?(nil, failure)
        }
        let controller = makeController(provider: provider)
        let cancelled = expectation(description: "Report attachment error")
        controller.context.onCancel = { error in
            XCTAssertEqual((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError, failure)
            cancelled.fulfill()
        }
        controller.onRedirect = { XCTFail("A failed attachment must not start an import") }

        controller.viewWillAppear(false)
        await fulfillment(of: [cancelled], timeout: 5)
        XCTAssertFalse(controller.context.completed)
    }

    private func makeController(provider: NSItemProvider) -> RecordingShareViewController {
        let item = NSExtensionItem()
        item.attachments = [provider]
        let controller = RecordingShareViewController()
        controller.context.items = [item]
        return controller
    }

    private func opml(feed: String) -> Data {
        Data("<opml version=\"1.0\"><body><outline type=\"rss\" xmlUrl=\"\(feed)\"/></body></opml>".utf8)
    }
}

@MainActor
private final class RecordingShareViewController: ShareViewController {
    let context = RecordingExtensionContext()
    var redirectedURL: URL?
    var onRedirect: (() -> Void)?

    override var extensionContext: NSExtensionContext? { context }

    override func redirectToHostApp(_ url: String) {
        redirectedURL = URL(string: url)
        onRedirect?()
    }
}

private final class RecordingExtensionContext: NSExtensionContext {
    var items: [NSExtensionItem] = []
    var completed = false
    var error: Error?
    var onCancel: ((Error) -> Void)?

    override var inputItems: [Any] { items }

    override func completeRequest(returningItems items: [Any]?, completionHandler: ((Bool) -> Void)? = nil) {
        completed = true
    }

    override func cancelRequest(withError error: Error) {
        self.error = error
        onCancel?(error)
    }
}
