import PocketCastsServer
import PocketCastsUtils
import UIKit

class FeaturedSummaryViewController: SimpleNotificationsViewController, GridLayoutDelegate, UICollectionViewDataSource, UICollectionViewDelegate, DiscoverSummaryProtocol, TinyPageControlDelegate {
    @IBOutlet var featuredCollectionView: ThemeableCollectionView!
    @IBOutlet var pageControl: TinyPageControl! {
        didSet {
            pageControl.delegate = self
        }
    }

    private var podcasts = [DiscoverPodcast]()

    private static let cellId = "FeaturedCollectionViewCell"

    private var maxCellWidth = 400 as CGFloat
    private var cellHeight: CGFloat {
        return DiscoverFeaturedView.scaledHeight
    }

    private var listType: String = ""
    private var lastLayedOutWidth = 0 as CGFloat
    private let maxFeaturedItems = 5

    private weak var delegate: DiscoverDelegate?
    private var category: DiscoverCategory?

    var serverHandler: DiscoverServerHandling = DiscoverServerHandler.shared
    @IBOutlet var featuredCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet var dividerHeightConstraint: NSLayoutConstraint! {
        didSet {
            applyHairlineWidth(to: dividerHeightConstraint)
        }
    }

    private var horizontalSafeAreaInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: view.safeAreaInsets.left, bottom: 0, right: view.safeAreaInsets.right)
    }

    // MARK: - View Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: FeaturedSummaryViewController, _) in
            controller.updateSize()
        }

        (view as? ThemeableView)?.style = .primaryUi02

        featuredCollectionView.register(UINib(nibName: "FeaturedCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: FeaturedSummaryViewController.cellId)
        featuredCollectionView.contentInsetAdjustmentBehavior = .never

        let gridLayout = featuredCollectionView.collectionViewLayout as! GridLayout

        gridLayout.delegate = self
        gridLayout.numberOfRowsOrColumns = 1
        gridLayout.scrollDirection = .horizontal

        maxCellWidth = view.bounds.width

        NotificationCenter.default.addObserver(self, selector: #selector(podcastStatusChanged), name: Constants.Notifications.podcastAdded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(podcastStatusChanged), name: Constants.Notifications.podcastDeleted, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if lastLayedOutWidth != view.bounds.width {
            lastLayedOutWidth = view.bounds.width
            maxCellWidth = view.bounds.width
            featuredCollectionViewHeight.constant = cellHeight
            featuredCollectionView.reloadData()

            updatePageCount()
        }
    }

    /// The safe area also changes vertically as the row scrolls under the bars, so the visible cells follow the horizontal insets without a reload.
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        for case let cell as FeaturedCollectionViewCell in featuredCollectionView.visibleCells {
            cell.featuredView.contentInsets = horizontalSafeAreaInsets
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        featuredCollectionView.reloadData()
        featuredCollectionView.initializeAutoScrollTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        featuredCollectionView.stopAutoScrollTimer()
    }

    @objc private func podcastStatusChanged(notificiation: Notification) {
        guard let object = notificiation.object else { return }
        let uuid = object as! String
        if let index = podcasts.firstIndex(where: { $0.uuid == uuid }) {
            featuredCollectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
        }
    }

    // MARK: - GridLayoutDelegate

    func scaleForItem(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, atIndexPath indexPath: IndexPath) -> UInt {
        2
    }

    func sizeForItem(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, atIndexPath indexPath: IndexPath) -> CGSize {
        CGSize(width: maxCellWidth, height: cellHeight)
    }

    // MARK: - UICollectionView Methods

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedSummaryViewController.cellId, for: indexPath) as! FeaturedCollectionViewCell

        cell.featuredView.contentInsets = horizontalSafeAreaInsets

        let podcast = podcasts[indexPath.row]
        if let delegate {
            cell.populateFrom(podcast, isSubscribed: delegate.isSubscribed(podcast: podcast), listName: listType)
            cell.featuredView.onSubscribe = {
                delegate.subscribe(podcast: podcast)
            }
        }

        if let uuid = podcast.uuid {
            ColorManager.darkThemeTintColor(forPodcastUuid: uuid, completion: { (color: UIColor) in
                DispatchQueue.main.async {
                    cell.setPodcastColor(color)
                }
            })
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let delegate else { return }

        let podcast = podcasts[indexPath.row]
        delegate.show(discoverPodcast: podcast, placeholderImage: nil, isFeatured: true, listUuid: nil)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        podcasts.count
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentPage()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        featuredCollectionView.initializeAutoScrollTimer()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        featuredCollectionView.stopAutoScrollTimer()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        AppTheme.defaultStatusBarStyle()
    }

    // MARK: - DiscoverSummaryProtocol

    func populateFrom(item: DiscoverItem, region: String?, category: DiscoverCategory?) {
        guard let source = item.source, let title = item.title?.localized else { return }

        if let delegate {
            listType = delegate.replaceRegionName(string: title)
        }

        self.category = category

        serverHandler.discoverPodcastList(source: source) { [weak self] podcastList in
            DispatchQueue.main.async {
                guard let self, let podcasts = podcastList?.podcasts else { return }
                self.podcasts = Array(podcasts.prefix(self.maxFeaturedItems))
                self.updatePageCount()
                self.featuredCollectionView.reloadData()
            }
        }
    }

    func registerDiscoverDelegate(_ delegate: DiscoverDelegate) {
        self.delegate = delegate
    }

    // MARK: - TinyPageControl delegate

    func pageDidChange(_ newPage: Int) {
        let offset = CGFloat(newPage) * featuredCollectionView.bounds.width
        featuredCollectionView.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
    }

    private func updatePageCount() {
        let numberOfPages = maxFeaturedItems < podcasts.count ? podcasts.count : maxFeaturedItems
        if numberOfPages == 0 { return }

        pageControl.numberOfPages = numberOfPages
        updateCurrentPage()
    }

    private func updateCurrentPage() {
        guard featuredCollectionView.frame.width != .zero else { return }
        let currentPage = Int(round(featuredCollectionView.contentOffset.x / featuredCollectionView.frame.width))

        if currentPage == pageControl.currentPage { return }
        pageControl.currentPage = currentPage
    }

    // MARK: - Dynamic Type support

    func updateSize() {
        lastLayedOutWidth = 0
        featuredCollectionViewHeight.constant = cellHeight
    }
}

#if DEBUG

import SwiftUI

#Preview("Featured carousel") {
    let section = FeaturedSummaryViewController()
    section.serverHandler = PreviewDiscoverServerHandler(
        podcastList: DiscoverPreviewData.podcastList(title: "Featured", podcasts: DiscoverPreviewData.podcasts(5))
    )
    return DiscoverSectionPreview(
        section: section,
        item: DiscoverPreviewData.item(.featuredSummary, title: "Featured")
    )
}

#endif
