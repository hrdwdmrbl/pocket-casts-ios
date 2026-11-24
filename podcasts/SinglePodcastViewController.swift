import PocketCastsServer
import PocketCastsUtils
import UIKit

class SinglePodcastViewController: UIViewController, DiscoverSummaryProtocol {
    @IBOutlet var podcastImage: PodcastImageView!

    @IBOutlet var podcastTitle: ThemeableLabel! {
        didSet {
            podcastTitle.font = .font(ofSize: 19, weight: .bold, scalingWith: .title3)
            podcastTitle.adjustsFontForContentSizeCategory = true
            podcastTitle.updateNumberOfLines(regular: 2, accessibility: 3)
        }
    }
    @IBOutlet var podcastDescription: ThemeableLabel! {
        didSet {
            podcastDescription.style = .primaryText02
            podcastDescription.adjustsFontForContentSizeCategory = true
        }
    }

    @IBOutlet var typeBadgeLabel: ThemeableLabel! {
        didSet {
            typeBadgeLabel.layer.cornerRadius = 4
            typeBadgeLabel.font = .font(ofSize: 13, weight: .semibold, scalingWith: .footnote)
            typeBadgeLabel.adjustsFontForContentSizeCategory = true
            typeBadgeLabel.adjustsFontSizeToFitWidth = true
        }
    }

    @IBOutlet var subscribeButton: BouncyButton! {
        didSet {
            subscribeButton.tintColor = ThemeColor.primaryIcon02()
            subscribeButton.onImage = UIImage(named: "discover_tick")?.tintedImage(ThemeColor.support02())
            subscribeButton.offImage = UIImage(named: "discover_add")?.tintedImage(ThemeColor.primaryIcon02())

            subscribeButton.offAccessibilityLabel = L10n.follow
            subscribeButton.onAccessibilityLabel = L10n.unfollow
        }
    }

    @IBOutlet var titleToDescriptionConstraint: NSLayoutConstraint!
    private weak var delegate: DiscoverDelegate?

    var serverHandler: DiscoverServerHandling = DiscoverServerHandler.shared
    private var podcast: DiscoverPodcast?
    private var item: DiscoverItem?
    private var featuredDescription: String?
    private var region: String?
    private var category: DiscoverCategory?

    override func viewDidLoad() {
        super.viewDidLoad()
        (view as? ThemeableView)?.style = .primaryUi02

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: SinglePodcastViewController, _) in
            controller.updateSize()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showPodcast))
        view.addGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
        view.translatesAutoresizingMaskIntoConstraints = false

        populate()
    }

    func registerDiscoverDelegate(_ delegate: DiscoverDelegate) {
        self.delegate = delegate
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        populate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateSize()
    }

    // MARK: DiscoverSummaryProtocol

    func populateFrom(item: DiscoverItem, region: String?, category: DiscoverCategory?) {
        guard let source = item.source else { return }

        self.item = item
        self.region = region
        self.category = category
        serverHandler.discoverPodcastList(source: source, completion: { [weak self] podcastList in
            guard let discoverPodcast = podcastList?.podcasts else { return }

            self?.podcast = discoverPodcast.first
            self?.featuredDescription = podcastList?.description
            DispatchQueue.main.async {
                self?.populate()
            }
        })
    }

    // MARK: Populate UI

    func populate() {
        guard let podcast else { return }

        if let title = podcast.title?.localized {
            podcastTitle?.text = title
            let maxTitleChars = podcastTitle.bounds.width * 0.11
            let fontSize: CGFloat = title.count > Int(maxTitleChars) ? 15 : 18
            podcastTitle.font = .font(ofSize: fontSize, weight: .bold, scalingWith: .body)
            titleToDescriptionConstraint.constant = fontSize == 15 ? 4 : 6
        }
        if let description = featuredDescription {
            podcastDescription.text = description
        }
        if let uuid = podcast.uuid {
            podcastImage?.setPodcast(uuid: uuid, size: .grid)
        }
        typeBadgeLabel.text = L10n.discoverFreshPick
        typeBadgeLabel.style = .support02

        let fontSize: CGFloat = view.bounds.width >= 360 ? 15 : 14
        podcastDescription.font = .font(ofSize: fontSize, weight: .regular, scalingWith: .callout)

        updateSize()
        podcastTitle.sizeToFit()
        podcastDescription.sizeToFit()

        subscribeButton.shouldAnimate = false
        subscribeButton.currentlyOn = delegate?.isSubscribed(podcast: podcast) ?? false
        subscribeButton.shouldAnimate = true

        view.sizeToFit()
        view.layoutIfNeeded()
    }

    // MARK: Actions

    @IBAction func subscribeTapped(_ sender: Any) {
        guard !subscribeButton.currentlyOn, let podcast else { return }

        subscribeButton.currentlyOn = true

        delegate?.subscribe(podcast: podcast)
    }

    @objc func showPodcast() {
        guard let podcast else { return }

        delegate?.show(discoverPodcast: podcast, placeholderImage: nil, isFeatured: true, listUuid: item?.uuid)
    }

    // MARK: / Notifications

    @objc func themeDidChange() {
        subscribeButton.tintColor = ThemeColor.primaryIcon02()
        subscribeButton.onImage = UIImage(named: "discover_tick")?.tintedImage(ThemeColor.support02())
        subscribeButton.offImage = UIImage(named: "discover_add")?.tintedImage(ThemeColor.primaryIcon02())

        updateTypeBadgeColors()
    }

    private func updateTypeBadgeColors() {
        typeBadgeLabel.style = .support02
    }

    func updateSize() {
        podcastTitle.updateNumberOfLines(regular: 2, accessibility: 3)
        podcastDescription.updateNumberOfLines(regular: 4, accessibility: 6)
    }
}

#if DEBUG

import SwiftUI

#Preview("Single podcast · fresh pick") {
    let section = SinglePodcastViewController()
    section.serverHandler = PreviewDiscoverServerHandler(
        podcastList: DiscoverPreviewData.podcastList(
            title: "Fresh pick",
            description: "Whispered tales and trivia to help you fall asleep, three nights a week.",
            podcasts: [DiscoverPreviewData.podcast(at: 2)]
        )
    )
    return DiscoverSectionPreview(
        section: section,
        item: DiscoverPreviewData.item(.singlePodcast, title: "Fresh pick")
    )
}

#endif
