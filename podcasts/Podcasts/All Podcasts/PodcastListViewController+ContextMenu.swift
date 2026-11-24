import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit

extension PodcastListViewController {
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        // While editing the order, taps and gestures are reserved for drag-to-reorder.
        guard !isEditingOrder, let item = itemAt(indexPath: indexPath), !item.isEmpty else {
            return nil
        }
        if let podcast = item.podcast {
            return makePodcastContextMenu(for: podcast, at: indexPath)
        }

        return nil
    }

    // MARK: Configuration builders

    private func makePodcastContextMenu(for podcast: Podcast, at indexPath: IndexPath) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: indexPath as NSCopying,
            previewProvider: {
                PodcastPreviewViewController(podcastUUID: podcast.uuid)
            },
            actionProvider: { [weak self] _ in
                self?.makePodcastMenu(for: podcast, at: indexPath)
            }
        )
    }

    // MARK: Menus

    private func makePodcastMenu(for podcast: Podcast, at indexPath: IndexPath) -> UIMenu {
        let shareAction = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self else { return }
            let cell = self.podcastsCollectionView.cellForItem(at: indexPath)
            let sourceRect = cell.map { self.podcastsCollectionView.convert($0.frame, to: self.view) } ?? .zero
            SharingHelper.shared.shareLinkTo(podcast: podcast,
                                             fromController: self,
                                             sourceRect: sourceRect,
                                             sourceView: self.view)
        }
        let topRow = UIMenu(title: "", options: .displayInline, preferredElementSize: .medium, children: [shareAction])

        let notificationsOn = podcast.pushEnabled
        let onAction = UIAction(title: L10n.on, state: notificationsOn ? .on : .off) { _ in
            if !notificationsOn {
                NotificationsHelper.shared.setNotificationsEnabled(true, for: podcast)
            }
        }
        let offAction = UIAction(title: L10n.off, state: notificationsOn ? .off : .on) { _ in
            if notificationsOn {
                NotificationsHelper.shared.setNotificationsEnabled(false, for: podcast)
            }
        }
        let notificationsMenu = UIMenu(title: notificationsOn ? L10n.notificationsOn : L10n.notificationsOff,
                                       image: UIImage(systemName: notificationsOn ? "bell" : "bell.slash"),
                                       options: .singleSelection,
                                       children: [onAction, offAction])

        let editAction = UIAction(title: L10n.podcastsEdit, image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
            self?.setEditingOrder(true)
        }

        let unfollowAction = UIAction(title: L10n.unfollow, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmUnsubscribe(podcast: podcast)
        }

        return UIMenu(title: "", children: [topRow, notificationsMenu, editAction, unfollowAction])
    }

    // MARK: Action handlers

    private func confirmUnsubscribe(podcast: Podcast) {
        let alert = UIAlertController(title: L10n.areYouSure, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.unfollow, style: .destructive) { _ in
            PodcastManager.shared.unsubscribe(podcast: podcast)
        })
        present(alert, animated: true)
    }
}
