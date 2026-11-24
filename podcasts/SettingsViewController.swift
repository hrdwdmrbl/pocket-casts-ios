import PocketCastsServer
import PocketCastsUtils
import SwiftUI
import UIKit

class SettingsViewController: PCViewController, UITableViewDataSource, UITableViewDelegate {
    enum TableRow: String {
        case general, notifications, appearance, storageAndDataUse
        case autoArchive, autoDownload, autoAddToUpNext, siriShortcuts
        case importSteps, opml
        case downloaded, starred, listeningHistory, allStats, uploadedFiles
        case about
        case upNextHistory
        case headphoneControls

        var display: (text: String, image: UIImage?) {
            switch self {
            case .downloaded:
                return (L10n.downloads, UIImage(named: "profile-download"))
            case .starred:
                return (L10n.statusStarred, UIImage(named: "filter_starred"))
            case .listeningHistory:
                return (L10n.listeningHistory, UIImage(named: "profile-history"))
            case .allStats:
                return (L10n.settingsStats, UIImage(named: "profile-stats"))
            case .uploadedFiles:
                return (L10n.files, UIImage(named: "profile_files"))
            case .general:
                return (L10n.settingsGeneral, UIImage(named: "profile-settings"))
            case .notifications:
                return (L10n.settingsNotifications, UIImage(named: "settings_notifications"))
            case .appearance:
                return (L10n.settingsAppearance, UIImage(named: "settings_appearance"))
            case .storageAndDataUse:
                return (L10n.settingsStorage, UIImage(named: "settings_storage"))
            case .autoArchive:
                return (L10n.settingsAutoArchive, UIImage(named: "settings_archive"))
            case .autoAddToUpNext:
                return (L10n.settingsAutoAdd, UIImage(named: "playlast"))
            case .autoDownload:
                return (L10n.settingsAutoDownload, UIImage(named: "settings_autodownload"))
            case .importSteps:
                return (L10n.welcomeImportButton, UIImage(named: "settings_import_podcasts"))
            case .opml:
                return (L10n.exportPodcastsOption, UIImage(named: "settings_export_podcasts"))
            case .about:
                return (L10n.settingsAbout, UIImage(named: "settings_about"))
            case .siriShortcuts:
                return (L10n.settingsSiriShortcuts, UIImage(named: "settings_shortcuts"))
            case .headphoneControls:
                return (L10n.settingsHeadphoneControls, .init(named: "settings_headphone_controls"))
            case .upNextHistory:
                return (L10n.upNextHistory, .init(named: "upnext"))
            }
        }
    }

    private var tableData: [[TableRow]] = []

    /// All the possible settings sections
    private let allSections: [[TableRow]] = [
        [.downloaded, .starred, .listeningHistory, .allStats, .uploadedFiles],
        [.general, .notifications, .appearance],
        [.autoArchive, .autoDownload, .autoAddToUpNext],
        [.storageAndDataUse, .siriShortcuts, .headphoneControls],
        [.importSteps, .opml],
        [.upNextHistory],
        [.about]
    ]

    private let settingsCellId = "SettingsCell"

    @IBOutlet var settingsTable: UITableView! {
        didSet {
            settingsTable.register(UINib(nibName: "TopLevelSettingsCell", bundle: nil), forCellReuseIdentifier: settingsCellId)
            settingsTable.rowHeight = UITableView.automaticDimension
            settingsTable.estimatedRowHeight = UITableView.automaticDimension
            settingsTable.sectionHeaderHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionHeaderHeight = Constants.Values.tableSectionHeaderHeight
            settingsTable.sectionFooterHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionFooterHeight = Constants.Values.tableSectionHeaderHeight
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.settings
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: settingsTable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadTable()
    }

    // MARK: - UITableView Methods

    func numberOfSections(in tableView: UITableView) -> Int {
        tableData.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: settingsCellId, for: indexPath) as! TopLevelSettingsCell

        let tableRow = tableData[indexPath.section][indexPath.row]
        cell.settingsLabel.text = tableRow.display.text
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = tableRow.display.text
        cell.accessibilityIdentifier = tableRow.rawValue
        cell.accessibilityTraits.insert(.button)
        cell.settingsImage.image = tableRow.display.image

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let tableRow = tableData[indexPath.section][indexPath.row]
        selectRow(tableRow)
    }

    func selectRow(_ tableRow: TableRow) {
        switch tableRow {
        case .downloaded:
            navigationController?.pushViewController(DownloadsViewController(), animated: true)
        case .starred:
            navigationController?.pushViewController(StarredViewController(), animated: true)
        case .listeningHistory:
            navigationController?.pushViewController(ListeningHistoryViewController(), animated: true)
        case .allStats:
            navigationController?.pushViewController(StatsViewController(), animated: true)
        case .uploadedFiles:
            navigationController?.pushViewController(UploadedViewController(), animated: true)
        case .general:
            navigationController?.pushViewController(GeneralSettingsViewController(), animated: true)
        case .notifications:
            navigationController?.pushViewController(NotificationsViewController(), animated: true)
        case .appearance:
            navigationController?.pushViewController(AppearanceViewController(), animated: true)
        case .storageAndDataUse:
            navigationController?.pushViewController(StorageAndDataUseViewController(), animated: true)
        case .autoAddToUpNext:
            navigationController?.pushViewController(AutoAddToUpNextViewController(), animated: true)
        case .autoArchive:
            navigationController?.pushViewController(AutoArchiveViewController(), animated: true)
        case .autoDownload:
            navigationController?.pushViewController(DownloadSettingsViewController(), animated: true)
        case .importSteps:
            let controller = ImportViewModel.make()
            navigationController?.present(controller, animated: true)
        case .opml:
            navigationController?.pushViewController(ImportExportViewController(), animated: true)
        case .about:

            let aboutView = AboutView()
                .environmentObject(Theme.shared)
            let hostingController = PCHostingController(rootView: aboutView)

            navigationController?.present(hostingController, animated: true, completion: nil)
        case .siriShortcuts:
            navigationController?.pushViewController(SiriSettingsViewController(), animated: true)
        case .headphoneControls:
            navigationController?.pushViewController(HeadphoneSettingsViewController(), animated: true)
        case .upNextHistory:
            let upNextHistory = UpNextHistoryViewController()
            navigationController?.pushViewController(upNextHistory, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        1
    }

    private func reloadTable() {
        tableData = allSections

        settingsTable.reloadData()
    }
}
