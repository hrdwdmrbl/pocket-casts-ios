import PocketCastsDataModel
import PocketCastsUtils
import UIKit

class ImportExportViewController: PCViewController, UIDocumentInteractionControllerDelegate {
    private var loadingAlert: ShiftyLoadingAlert?

    private var opmlShareController: UIDocumentInteractionController?

    @IBOutlet var importPocdcastsTitle: UILabel! {
        didSet {
            importPocdcastsTitle.text = L10n.importPodcastsTitle.localizedUppercase
        }
    }

    @IBOutlet var importPodcastsDescription: ThemeableLabel! {
        didSet {
            importPodcastsDescription.text = L10n.importPodcastsDescriptionNew
        }
    }

    @IBOutlet var exportPodcastsTitle: UILabel! {
        didSet {
            exportPodcastsTitle.text = L10n.exportPodcastsTitle.localizedUppercase
        }
    }

    @IBOutlet var exportPodcastsDescription: ThemeableLabel! {
        didSet {
            exportPodcastsDescription.text = L10n.exportPodcastsDescription
        }
    }

    @IBOutlet var importView: ThemeableView! {
        didSet {
            importView.style = .primaryUi01Active
        }
    }

    @IBOutlet var exportView: ThemeableView! {
        didSet {
            exportView.style = .primaryUi01Active
        }
    }

    @IBOutlet var importImage: UIImageView! {
        didSet {
            importImage.image = Theme.isDarkTheme ? UIImage(named: "settings_importillustration_dark") : UIImage(named: "settings_importillustration")
        }
    }

    @IBOutlet var exportBtn: UIButton! {
        didSet {
            exportBtn.setTitle(L10n.exportPodcastsOption, for: .normal)
            exportBtn.titleLabel?.font = .font(ofSize: 13, scalingWith: .subheadline)
            exportBtn.titleLabel?.adjustsFontForContentSizeCategory = true
            exportBtn.titleLabel?.numberOfLines = 0
            exportBtn.titleLabel?.lineBreakMode = .byWordWrapping
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.exportPodcastsOption
    }

    @IBOutlet var mainScrollView: UIScrollView!

    @IBAction func exportPodcasts(_ sender: AnyObject) {
        loadingAlert = ShiftyLoadingAlert(title: L10n.settingsExportOpml)
        loadingAlert?.showAlert(self, hasProgress: false, completion: {
            self.startExport()
        })
    }

    private func startExport() {
        let podcasts = DataManager.shared.allPodcasts(includeUnsubscribed: false)

        Task { @MainActor in
            do {
                let url = try await OpmlExporter(podcasts: podcasts).export()
                hideLoadingAlert()
                shareOpmlDocument(at: url)
            } catch {
                hideLoadingAlert()
                presentError()
            }
        }
    }

    private func hideLoadingAlert() {
        loadingAlert?.hideAlert(false)
        loadingAlert = nil
    }

    private func shareOpmlDocument(at url: URL) {
        opmlShareController = UIDocumentInteractionController(url: url)
        opmlShareController?.delegate = self

        let presentRect = view.convert(exportBtn.frame, from: exportBtn.superview)
        opmlShareController?.presentOptionsMenu(from: presentRect, in: view, animated: true)
    }

    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        opmlShareController = nil
    }

    private func presentError() {
        SJUIUtils.showAlert(title: L10n.settingsExportError, message: L10n.settingsExportErrorMsg, from: self)
    }
}
