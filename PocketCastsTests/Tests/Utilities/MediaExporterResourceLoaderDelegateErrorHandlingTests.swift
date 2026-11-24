import XCTest
import AVFoundation
import Network
import PocketCastsUtils
@testable import podcasts

final class MediaExporterResourceLoaderDelegateErrorHandlingTests: XCTestCase {

    var tempFilePath: String!

    override func setUp() {
        super.setUp()
        tempFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString + "_delegate_error_test.media")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempFilePath)
        tempFilePath = nil
        super.tearDown()
    }

    func testCancelledDownloadDeletesPartialFileAndReportsCancellation() async throws {
        // Hold a local HTTP response open so reset must cancel an active URLSession.
        let listener = try NWListener(using: .tcp, on: .any)
        let listening = expectation(description: "Local server ready")
        let serverQueue = DispatchQueue(label: "AppResetTests.server")
        let connection = Mutex<NWConnection?>(nil)
        listener.stateUpdateHandler = { state in
            if case .ready = state { listening.fulfill() }
        }
        listener.newConnectionHandler = { client in
            connection.withLock { $0 = client }
            client.start(queue: serverQueue)
            client.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
                let response = "HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: 1000000\r\n\r\npartial audio"
                client.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
            }
        }
        listener.start(queue: serverQueue)
        defer {
            connection.withLock { $0?.cancel() }
            listener.cancel()
        }
        await fulfillment(of: [listening], timeout: 3)
        let port = try XCTUnwrap(listener.port)
        let downloading = expectation(description: "Download started")
        let cancelled = expectation(description: "Download cancelled")
        let delegate = MediaExporterResourceLoaderDelegate(saveFilePath: tempFilePath) { status, _, _, _ in
            switch status {
            case .downloading:
                downloading.fulfill()
            case .failed(let error) where (error as? URLError)?.code == .cancelled:
                cancelled.fulfill()
            default:
                XCTFail("Unexpected download status: \(status)")
            }
        }
        delegate.startDataRequest(with: URL(string: "http://127.0.0.1:\(port.rawValue)/episode.mp3")!)
        await fulfillment(of: [downloading], timeout: 3)

        await delegate.cancelDownload()

        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFilePath))
    }

    // MARK: - Failure callback propagation

    func testCallback_receivesFailedStatus_whenURLSessionCompletesWithError() {
        let expectation = XCTestExpectation(description: "Callback receives .failed")
        var capturedStatus: MediaExporterResourceLoaderDelegate.FileExportStatus?

        let delegate = MediaExporterResourceLoaderDelegate(saveFilePath: tempFilePath) { status, _, _, _ in
            capturedStatus = status
            expectation.fulfill()
        }

        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        delegate.urlSession(.shared, task: makeTask(), didCompleteWithError: error)

        wait(for: [expectation], timeout: 1.0)

        guard case .failed(let receivedError) = capturedStatus else {
            XCTFail("Expected .failed status, got \(String(describing: capturedStatus))")
            return
        }
        XCTAssertEqual((receivedError as NSError).code, NSURLErrorNotConnectedToInternet)
    }

    func testCallback_receivesFailedStatus_whenFileHandleUnableToOpenFile() {
        let expectation = XCTestExpectation(description: "Callback receives .failed on file error")
        var capturedStatus: MediaExporterResourceLoaderDelegate.FileExportStatus?

        let delegate = MediaExporterResourceLoaderDelegate(saveFilePath: tempFilePath) { status, _, _, _ in
            capturedStatus = status
            expectation.fulfill()
        }

        let fileError = MediaFileHandleError.unableToOpenFile
        delegate.urlSession(.shared, task: makeTask(), didCompleteWithError: fileError)

        wait(for: [expectation], timeout: 1.0)

        guard case .failed(let receivedError) = capturedStatus else {
            XCTFail("Expected .failed status, got \(String(describing: capturedStatus))")
            return
        }
        XCTAssertEqual(receivedError as? MediaFileHandleError, .unableToOpenFile)
    }

    func testCallback_receivesFailedStatus_whenReadPastEndOfFile() {
        let expectation = XCTestExpectation(description: "Callback receives .failed on end-of-file read")
        var capturedStatus: MediaExporterResourceLoaderDelegate.FileExportStatus?

        let delegate = MediaExporterResourceLoaderDelegate(saveFilePath: tempFilePath) { status, _, _, _ in
            capturedStatus = status
            expectation.fulfill()
        }

        let eofError = MediaFileHandleError.readAfterEndOfFile
        delegate.urlSession(.shared, task: makeTask(), didCompleteWithError: eofError)

        wait(for: [expectation], timeout: 1.0)

        guard case .failed(let receivedError) = capturedStatus else {
            XCTFail("Expected .failed status, got \(String(describing: capturedStatus))")
            return
        }
        XCTAssertEqual(receivedError as? MediaFileHandleError, .readAfterEndOfFile)
    }

    func testCallback_isNotCalledWithFailed_whenSessionCompletesSuccessfully() {
        // A successful completion with no buffered data and no response verification error
        // should call the callback with .completed, not .failed.
        let expectation = XCTestExpectation(description: "Callback receives .completed")
        var capturedStatus: MediaExporterResourceLoaderDelegate.FileExportStatus?

        let delegate = MediaExporterResourceLoaderDelegate(saveFilePath: tempFilePath) { status, _, _, _ in
            if case .completed = status {
                capturedStatus = status
                expectation.fulfill()
            }
        }

        let previousMinimumExpectedFileSize = MediaExporterItemConfiguration.minimumExpectedFileSize
        defer { MediaExporterItemConfiguration.minimumExpectedFileSize = previousMinimumExpectedFileSize }
        MediaExporterItemConfiguration.minimumExpectedFileSize = 0

        delegate.urlSession(.shared, task: makeTask(), didCompleteWithError: nil)

        wait(for: [expectation], timeout: 1.0)

        guard case .completed = capturedStatus else {
            XCTFail("Expected .completed status, got \(String(describing: capturedStatus))")
            return
        }
    }
}

// MARK: - Helpers

private func makeTask() -> URLSessionTask {
    URLSession.shared.dataTask(with: URL(filePath: "/dev/null"))
}
