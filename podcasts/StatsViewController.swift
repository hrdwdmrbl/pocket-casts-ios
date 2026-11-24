import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import SwiftUI
import UIKit

class StatsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let statsCellId = "StatsCell"
    private let statsHeaderCellId = "StatsHeaderCell"
    private let heatmapCellId = "HeatmapCell"

    private enum StatsSection {
        case header
        case heatmap
        case timeSavedBreakdown
        case timeSavedTotal
    }

    private let sections: [StatsSection] = [.header, .heatmap, .timeSavedBreakdown, .timeSavedTotal]

    let playbackTimeHelper = PlaybackTimeHelper()
    private let heatmapViewModel = ListeningHeatmapViewModel()

    @IBOutlet var statsTable: UITableView! {
        didSet {
            statsTable.register(UINib(nibName: "StatsCell", bundle: nil), forCellReuseIdentifier: statsCellId)
            statsTable.register(UINib(nibName: "StatsTopCell", bundle: nil), forCellReuseIdentifier: statsHeaderCellId)
            statsTable.register(UINib(nibName: "StatsCell", bundle: nil), forCellReuseIdentifier: heatmapCellId)
            statsTable.contentInset = UIEdgeInsets(top: -35, left: 0, bottom: Constants.Values.miniPlayerOffset, right: 0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.settingsStats
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        heatmapViewModel.load()
        statsTable.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .header, .heatmap, .timeSavedTotal:
            return 1
        case .timeSavedBreakdown:
            return 4
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerFrame = CGRect(x: 0, y: 0, width: 0, height: Constants.Values.tableSectionHeaderHeight)

        switch sections[section] {
        case .heatmap:
            let header = SettingsTableHeader(frame: headerFrame, title: L10n.statsListeningActivitySectionTitle)
            header.addInfoButton(selector: #selector(showHeatmapInfo), target: self, accessibilityLabel: L10n.statsListeningActivityInfoAccessibilityLabel)
            return header
        case .timeSavedBreakdown:
            return SettingsTableHeader(frame: headerFrame, title: L10n.statsTimeSaved)
        case .header, .timeSavedTotal:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .header:
            return UITableView.automaticDimension
        default:
            return 18
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .header:
            let castCell = tableView.dequeueReusableCell(withIdentifier: statsHeaderCellId, for: indexPath) as! StatsTopCell
            castCell.loadingIndicator.stopAnimating()
            castCell.descriptionLabel.text = FunnyTimeConverter.timeSecsToFunnyText(totalTimeStat())
            castCell.timeLabel.text = formatStat(totalTimeStat())
            castCell.listenLabel.text = L10n.statsListenHistoryNoDate
            castCell.accessibilityLabel = L10n.statsAccessibilityListenHistoryFormat(castCell.timeLabel.text ?? "", castCell.descriptionLabel.text ?? "")
            return castCell
        case .heatmap:
            let cell = tableView.dequeueReusableCell(withIdentifier: heatmapCellId, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                ListeningHeatmapView(viewModel: heatmapViewModel)
                    .environmentObject(Theme.shared)
                    .dynamicTypeSize(DynamicTypeSize.medium...DynamicTypeSize.accessibility2)
            }
            .margins(.all, 0)
            return cell
        case .timeSavedBreakdown:
            let castCell = tableView.dequeueReusableCell(withIdentifier: statsCellId, for: indexPath) as! StatsCell
            castCell.showIcon()
            if indexPath.row == 0 {
                castCell.statName.text = L10n.statsSkipping
                castCell.statsIcon.image = UIImage(named: "stats_skipping")
                castCell.statValue.text = formatStat(skippedStat())
            } else if indexPath.row == 1 {
                castCell.statName.text = L10n.statsVariableSpeed
                castCell.statsIcon.image = UIImage(named: "stats_speed")
                castCell.statValue.text = formatStat(variableSpeedStat())
            } else if indexPath.row == 2 {
                castCell.statName.text = L10n.settingsTrimSilence
                castCell.statsIcon.image = UIImage(named: "stats_silence")
                castCell.statValue.text = formatStat(silenceRemovedStat())
            } else if indexPath.row == 3 {
                castCell.statName.text = L10n.statsAutoSkip
                castCell.statsIcon.image = UIImage(named: "stats_skip_both")
                castCell.statValue.text = formatStat(autoSkipStat())
            }
            castCell.statValue.style = .primaryText02
            return castCell
        case .timeSavedTotal:
            let castCell = tableView.dequeueReusableCell(withIdentifier: statsCellId, for: indexPath) as! StatsCell
            castCell.statName.text = L10n.statsTotal
            castCell.statValue.text = formatStat(skippedStat() + variableSpeedStat() + silenceRemovedStat() + autoSkipStat())
            castCell.statValue.style = .support01
            castCell.hideIcon()
            return castCell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .header:
            return 200
        case .heatmap:
            return 180
        case .timeSavedBreakdown, .timeSavedTotal:
            return 44
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        AppTheme.defaultStatusBarStyle()
    }

    private func skippedStat() -> Double {
        StatsManager.shared.totalSkippedTime()
    }

    private func variableSpeedStat() -> Double {
        StatsManager.shared.timeSavedVariableSpeed()
    }

    private func silenceRemovedStat() -> Double {
        StatsManager.shared.timeSavedDynamicSpeed()
    }

    private func autoSkipStat() -> Double {
        StatsManager.shared.totalAutoSkippedTime()
    }

    private func totalTimeStat() -> Double {
        StatsManager.shared.totalListeningTime()
    }

    private func formatStat(_ stat: Double) -> String {
        stat.localizedTimeDescription ?? L10n.statsTimeZeroSeconds
    }

    @objc private func showHeatmapInfo() {

        let view = ModalMessageView(
            title: L10n.statsListeningActivityInfoTitle,
            message: L10n.statsListeningActivityInfoMessage,
            actionTitle: L10n.gotIt
        )
        BottomSheetSwiftUIWrapper.present(
            view.environmentObject(Theme.shared),
            autoSize: true,
            showingGrabber: true,
            in: self
        )
    }
}
