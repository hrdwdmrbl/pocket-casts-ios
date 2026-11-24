import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import SwiftUI

extension PlaylistsViewController: UITableViewDelegate, UITableViewDataSource {
    func registerCells() {
        filtersTable.register(NewPlaylistCell.self, forCellReuseIdentifier: NewPlaylistCell.reuseIdentifier)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        listPlaylistItems.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return NewPlaylistCell.cellHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = cell(tableView, for: NewPlaylistCell.reuseIdentifier) as! NewPlaylistCell
        if cell.tag != indexPath.row { cell.reset() }
        cell.tag = indexPath.row
        if let playlist = listPlaylistItems[safe: indexPath.row]?.playlist {
            cell.set(playlistName: playlist.playlistName, isManualPlaylist: playlist.manual)
            cell.loadMetadata(for: playlist)
            cell.hideSeparator(indexPath.row == listPlaylistItems.count - 1)
        }
        return cell
    }

    private func cell(_ tableView: UITableView, for identifier: String) -> ThemeableCell? {
        if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? NewPlaylistCell {
            return cell
        }
        return NewPlaylistCell(style: .default, reuseIdentifier: identifier)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let filter = listPlaylistItems[safe: indexPath.row]?.playlist {
            showFilter(filter)
        }
    }

    // MARK: - Editing

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, let playlist = listPlaylistItems[safe: indexPath.row]?.playlist {
            showDeleteConfirmationDialog(for: playlist, at: indexPath, in: tableView)
        }
    }

    // MARK: - Cell reordering

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath == destinationIndexPath { return }

        let movedObject = listPlaylistItems[sourceIndexPath.row]
        listPlaylistItems.remove(at: sourceIndexPath.row)
        listPlaylistItems.insert(movedObject, at: destinationIndexPath.row)

        // ok, we've now sorted the list that needed sorting, update the sort positions in the DB and mark that list as not synced
        for (index, filter) in listPlaylistItems.enumerated() {
            DataManager.shared.updatePosition(playlist: filter.playlist, newPosition: Int32(index))
        }

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.playlistChanged)
    }
}

// MARK: - Delete

extension PlaylistsViewController {
    fileprivate func showDeleteConfirmationDialog(for playlist: EpisodeFilter, at indexPath: IndexPath, in tableView: UITableView) {

        let alert = UIAlertController(
            title: L10n.playlistsDeleteAlertTitle,
            message: L10n.playlistsDeleteAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel) { _ in
        })
        alert.addAction(UIAlertAction(title: L10n.delete, style: .destructive) { [weak self] _ in
            self?.delete(playlist: playlist, at: indexPath, in: tableView)
        })
        present(alert, animated: true)
    }

    fileprivate func delete(playlist: EpisodeFilter, at indexPath: IndexPath, in tableView: UITableView) {
        PlaylistManager.delete(playlist: playlist, fireEvent: false)
        listPlaylistItems.remove(at: indexPath.row)
        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .top)
        tableView.endUpdates()

        var properties: [String: Sendable] = [:]
        properties["filter_type"] = playlist.manual ? "manual" : "smart"
    }
}

extension PlaylistsViewController: UITableViewDragDelegate, UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let movedObject = listPlaylistItems[indexPath.row]
        let itemProvider = NSItemProvider(object: "\(movedObject.id)" as NSString)
        return [UIDragItem(itemProvider: itemProvider)]
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        coordinator.items.forEach { item in
            if let sourceIndexPath = item.sourceIndexPath {
                tableView.performBatchUpdates {
                    let movedItem = listPlaylistItems.remove(at: sourceIndexPath.row)
                    listPlaylistItems.insert(movedItem, at: destinationIndexPath.row)
                    tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
                }
                coordinator.drop(item.dragItem, toRowAt: destinationIndexPath)
            }
        }

        for (index, playlist) in listPlaylistItems.enumerated() {
            DataManager.shared.updatePosition(playlist: playlist.playlist, newPosition: Int32(index))
        }

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.playlistChanged)
    }
}
