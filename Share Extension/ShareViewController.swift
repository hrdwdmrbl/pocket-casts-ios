import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let content = extensionContext?.inputItems.first as? NSExtensionItem
        guard let attachment = content?.attachments?.first as? NSItemProvider else {
            close()
            return
        }

        let acceptedTypes: [UTType] = [.audio, .movie, .data]

        if let type = acceptedTypes.first(where: { attachment.hasItemConformingToTypeIdentifier($0.identifier) }) {
            loadFile(from: attachment, identifier: type.identifier)
        }
    }

    func redirectToHostApp(_ url: String) {
        guard let url = URL(string: "pktc://import-file/\(url)") else {
            return
        }

        let context = NSExtensionContext()
        context.open(url as URL, completionHandler: nil)
        var responder = self as UIResponder?

        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
            }
            responder = responder?.next
        }
    }

    private func loadFile(from attachment: NSItemProvider, identifier: String) {
        attachment.loadItem(forTypeIdentifier: identifier, options: nil) { [weak self] data, error in
            do {
                if let error { throw error }
                guard let url = data as? URL else {
                    throw CocoaError(.fileReadUnknown)
                }

                let fileManager = FileManager.default
                guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.GroupUserDefaults.groupContainerId) else {
                    throw CocoaError(.fileNoSuchFile)
                }

                let filename = identifier == UTType.data.identifier ? "opml.opml" : url.lastPathComponent
                let destination = container.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: url, to: destination)

                DispatchQueue.main.async {
                    self?.close()
                    self?.redirectToHostApp(destination.absoluteString)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.extensionContext?.cancelRequest(withError: error)
                }
            }
        }
    }

    private func close() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
