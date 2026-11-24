import PocketCastsServer
import UIKit
import PocketCastsUtils

class CategoryPodcastsViewController: PCViewController, UITableViewDelegate, UITableViewDataSource {
    private static let cellId = "DiscoverCell"
    @IBOutlet var podcastsTable: UITableView! {
        didSet {
            // This will remove extra separators from tableview
            podcastsTable.tableFooterView = UIView(frame: CGRect.zero)
            podcastsTable.register(UINib(nibName: "DiscoverPodcastTableCell", bundle: nil), forCellReuseIdentifier: CategoryPodcastsViewController.cellId)
        }
    }

    @IBOutlet var noNetworkView: UIView!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    weak var delegate: DiscoverDelegate?

    var serverHandler: DiscoverServerHandling = DiscoverServerHandler.shared

    fileprivate var item: DiscoverItem?

    fileprivate var category: DiscoverCategory? {
        didSet {
            title = category?.name?.localized
        }
    }
    private(set) var skipCount: Int
    private var podcasts = [DiscoverPodcast]()
    fileprivate var region: String?

    init(category: DiscoverCategory? = nil, region: String?, skipCount: Int = 0) {
        self.category = category
        self.region = region
        self.skipCount = skipCount
        super.init(nibName: "CategoryPodcastsViewController", bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: podcastsTable)
    }

    @IBAction func tryAgainTapped(_ sender: AnyObject) {
        loadPodcasts()
    }

    // MARK: - UITableView Methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        podcasts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let podcast = podcasts[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: CategoryPodcastsViewController.cellId, for: indexPath) as! DiscoverPodcastTableCell
        cell.populateFrom(podcast, number: -1)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let delegate else { return }

        if let cell = tableView.cellForRow(at: indexPath) as? DiscoverPodcastTableCell {
            let podcastIndexRow = indexPath.row
            let podcast = podcasts[podcastIndexRow]

            let categoryName = category?.name ?? "unknown"
            let listUuid = "category-\(categoryName.lowercased())-\(region ?? "unknown")"

            delegate.show(discoverPodcast: podcast, placeholderImage: cell.podcastImage.image, isFeatured: false, listUuid: listUuid)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }

    // MARK: - Loading

    private func loadPodcasts() {
        guard let delegate, let category, let source = delegate.replaceRegionCode(string: category.source) else { return }
        if loadingIndicator.isAnimating || !podcasts.isEmpty { return }

        noNetworkView.isHidden = true
        loadingIndicator.startAnimating()

        serverHandler.discoverCategoryDetails(source: source, completion: { [weak self] categoryDetails in
            DispatchQueue.main.async {
                guard let strongSelf = self, let podcasts = categoryDetails?.podcasts else {
                    return
                }

                strongSelf.loadingIndicator.stopAnimating()
                strongSelf.podcasts = Array(podcasts.dropFirst(strongSelf.skipCount))
                strongSelf.podcastsTable.reloadData()

                if let item = strongSelf.item {
                    strongSelf.delegate?.invalidate(item: item)
                }
            }
        })
    }

    private func handleLoadFailed() {
        noNetworkView.isHidden = false
    }

    func registerDiscoverDelegate(_ delegate: DiscoverDelegate) {
        self.delegate = delegate
    }

    /// Updates the skipCount from the item's summaryItemCount.
    /// This is used to skip podcasts already shown in the "Most Popular" carousel.
    func updateSkipCount(from item: DiscoverItem) {
        skipCount = max(0, item.summaryItemCount ?? 0)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        AppTheme.defaultStatusBarStyle()
    }
}

extension CategoryPodcastsViewController: DiscoverSummaryProtocol {
    func populateFrom(item: PocketCastsServer.DiscoverItem, region: String?, category: PocketCastsServer.DiscoverCategory?) {
        self.item = item
        if let category {
            self.category = category
        }
        self.region = region

        // Update skipCount from item to skip podcasts already shown in the carousel
        updateSkipCount(from: item)

        podcasts = []
        podcastsTable?.reloadData()
        loadPodcasts()
    }
}

#if DEBUG

import SwiftUI

#Preview("Category podcasts") {
    let section = CategoryPodcastsViewController(region: "us")
    section.serverHandler = PreviewDiscoverServerHandler(
        categoryDetails: DiscoverPreviewData.categoryDetails(title: "Technology", podcasts: DiscoverPreviewData.podcasts(12))
    )
    return DiscoverSectionPreview(
        section: section,
        item: DiscoverPreviewData.item(.categoryPodcasts, title: "Technology"),
        category: DiscoverPreviewData.categories()[11],
        height: 700
    )
}

#endif
