import PocketCastsServer
import UIKit

class UploadedSettingsViewController: PCViewController, UITableViewDelegate, UITableViewDataSource {
    private let switchCellId = "SwitchCell"
    private enum TableSections: Int { case autoAddToUpNext, afterPlaying }
    private enum TableRows: Int { case autoAddToUpNext, removeFileAfterPlaying }

    @IBOutlet var settingsTable: UITableView! {
        didSet {
            settingsTable.register(UINib(nibName: "SwitchCell", bundle: nil), forCellReuseIdentifier: switchCellId)

            settingsTable.rowHeight = UITableView.automaticDimension
            settingsTable.estimatedRowHeight = UITableView.automaticDimension
            settingsTable.sectionHeaderHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionHeaderHeight = Constants.Values.tableSectionHeaderHeight
            settingsTable.sectionFooterHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionFooterHeight = Constants.Values.tableSectionHeaderHeight
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        AppTheme.defaultStatusBarStyle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.settingsFiles
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: settingsTable)
    }

    private func tableSections() -> [TableSections] { [.autoAddToUpNext, .afterPlaying] }

    private func tableRows() -> [[TableRows]] { [[.autoAddToUpNext], [.removeFileAfterPlaying]] }

    // MARK: - UITableView Methods

    func numberOfSections(in tableView: UITableView) -> Int {
        tableSections().count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableRows()[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableRows()[indexPath.section][indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellId, for: indexPath) as! SwitchCell
        cell.cellSwitch.removeTarget(self, action: nil, for: UIControl.Event.valueChanged)

        switch row {
        case .autoAddToUpNext:
            cell.cellLabel?.text = L10n.settingsAutoAdd
            cell.setImage(imageName: "settings_upnext")
            cell.cellSwitch.isOn = Settings.userEpisodeAutoAddToUpNext
            cell.cellSwitch.addTarget(self, action: #selector(autoAddToUpNextToggled(_:)), for: .valueChanged)
        case .removeFileAfterPlaying:
            cell.cellLabel?.text = L10n.settingsFilesDeleteLocalFile
            cell.setImage(imageName: "delete")
            cell.cellSwitch.isOn = Settings.userEpisodeRemoveFileAfterPlaying
            cell.cellSwitch.addTarget(self, action: #selector(removeFileAfterPlayingToggled(_:)), for: .valueChanged)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = tableSections()[section]
        switch section {
        case .autoAddToUpNext:
            return L10n.settingsFilesAddUpNextSubtitle
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        ThemeableTable.setHeaderFooterTextColor(on: view)
    }

    @objc private func autoAddToUpNextToggled(_ sender: UISwitch) {
        Settings.userEpisodeAutoAddToUpNext = sender.isOn
    }

    @objc private func removeFileAfterPlayingToggled(_ sender: UISwitch) {
        Settings.userEpisodeRemoveFileAfterPlaying = sender.isOn
    }
}
