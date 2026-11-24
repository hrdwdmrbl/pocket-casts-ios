import Foundation
import SwiftUI
import PocketCastsUtils

class ImportViewModel: ObservableObject {
    var navigationController: UINavigationController?
    let availableSources: [ImportSource]

    init() {
        self.availableSources = supportedSources.filter { $0.isSourceAvailable }
    }

    @objc func dismissTapped() {
        navigationController?.dismiss(animated: true)
    }

    // MARK: - Import apps
    let supportedSources: [ImportSource] = [
        .init(id: .applePodcasts, displayName: "Apple Podcasts", steps: L10n.importInstructionsApplePodcastsSteps),
        .init(id: .breaker, displayName: "Breaker", steps: L10n.importInstructionsBreaker),
        .init(id: .castro, displayName: "Castro", steps: L10n.importInstructionsCastro),
        .init(id: .castbox, displayName: "Castbox", steps: L10n.importInstructionsCastbox),
        .init(id: .overcast, displayName: "Overcast", steps: L10n.importInstructionsOvercast),
        .init(id: .other, displayName: "other apps", steps: L10n.importPodcastsDescriptionNew),
        .init(id: .opmlFromURL, displayName: "URL", steps: L10n.importOpmlFromUrl)
    ]

    enum ImportSourceId: String {
        case breaker, castbox = "wazecastbox", overcast, other, opmlFromURL
        case castro = "co.supertop.Castro-2"
        case applePodcasts = "https://pocketcasts.com/import-from-apple-podcasts"
    }

    struct ImportSource: Identifiable, CustomDebugStringConvertible, Hashable {
        let id: ImportSourceId
        let displayName: String
        let steps: String

        var isSourceAvailable: Bool {
            #if targetEnvironment(simulator)
            return true
            #else
            // Always available - Others and opml from url are always available
            // Note: Even if Apple podcasts has been uninstalled by the user, the system will always report
            // that it's installed.
            if [.other, .applePodcasts, .opmlFromURL].contains(id) {
                return true
            }

            guard let url else {
                return false
            }

            return UIApplication.shared.canOpenURL(url)
            #endif
        }

        var hideButton: Bool {
            switch id {
            case .other:
                return true
            default:
                return false
            }
        }

        func openApp() {
            guard let url else { return }

            UIApplication.shared.open(url)
        }

        private var url: URL? {
            if id == .other || id == .opmlFromURL { return nil }

            let string: String
            if id == .applePodcasts {
                string = id.rawValue
            } else {
                string = id.rawValue + "://"
            }

            return URL(string: string)
        }

        var debugDescription: String {
            return "\(displayName): \(isSourceAvailable ? "Yes" : "No")"
        }
    }
}

extension ImportViewModel {
    static func make() -> UIViewController {
        let viewModel = ImportViewModel()

        let controller = ImportHostingController(rootView: ImportLandingView(viewModel: viewModel).setupDefaultEnvironment())

        let navController = UINavigationController(rootViewController: controller)
        viewModel.navigationController = navController
        controller.viewModel = viewModel

        return navController
    }
}

// MARK: - Landing View
extension ImportViewModel {
    func didSelect(_ importsource: ImportSource) {
        guard let navigationController else { return }

        let controller = ImportHostingController(rootView: ImportDetailsView(importSource: importsource, viewModel: self).setupDefaultEnvironment())
        controller.viewModel = self

        navigationController.pushViewController(controller, animated: true)
    }
}

// MARK: - Details
extension ImportViewModel {
    func openApp(_ app: ImportSource) {

        app.openApp()
    }
}

// MARK: - OPML from URL
extension ImportViewModel {
    func importFromURL(_ url: URL, completion: @escaping ((Bool) -> Void)) {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data else {
                print("Error downloading data: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }

            let temporaryDirectory = FileManager.default.temporaryDirectory
            let fileURL = temporaryDirectory.appendingPathComponent("feed.opml")

            do {
                try data.write(to: fileURL)
                print("File downloaded to: \(fileURL)")
                self.importPodcastsFromOPML(url: fileURL)
            } catch {
                print("Error saving file: \(error.localizedDescription)")
                completion(false)
            }
        }

        task.resume()
    }

    func importPodcastsFromOPML(url: URL) {
        PodcastManager.shared.importPodcastsFromOpml(url)
    }
}
