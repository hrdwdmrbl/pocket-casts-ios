import SwiftUI
import PocketCastsServer
import Combine
import PocketCastsUtils

class CategoriesSelectorViewController: ThemedHostingController<CategoriesSelectorView>, DiscoverSummaryProtocol {

    class DiscoverItemObservable: ObservableObject {
        @Published public var item: DiscoverItem?
        @Published public var selectedCategory: DiscoverCategory?
        @Published public var region: String?
        private(set) var cachedCategories = [DiscoverCategory]()

        var serverHandler: DiscoverServerHandling

        lazy var load: (() async -> (categories: [DiscoverCategory], prioritized: [DiscoverCategory])?) = { [weak self] in
            guard let self, let source = self.item?.source else { return ([], []) }

            let categories = await self.serverHandler.discoverCategories(source: source)

            // Determine which categories to work with
            let workingCategories: [DiscoverCategory]
            if let popular = self.item?.popular {
                workingCategories = categories.filter {
                    guard let id = $0.id else { return false }
                    return popular.contains(id)
                }
            } else {
                workingCategories = categories
            }

            self.cachedCategories = categories
            return (categories, workingCategories)
        }

        init(serverHandler: DiscoverServerHandling = DiscoverServerHandler.shared,
             load: (() async -> (categories: [DiscoverCategory], prioritized: [DiscoverCategory])?)? = nil) {
            self.serverHandler = serverHandler
            if let load {
                self.load = load
            }
        }
    }
    @ObservedObject fileprivate var observable: DiscoverItemObservable

    private weak var delegate: DiscoverDelegate?

    var serverHandler: DiscoverServerHandling {
        get { observable.serverHandler }
        set { observable.serverHandler = newValue }
    }

    private var cancellables: Set<AnyCancellable> = []

    func registerDiscoverDelegate(_ delegate: any DiscoverDelegate) {
        self.delegate = delegate
    }

    func setCategory(_ category: String) {
        for categoryObject in observable.cachedCategories {
            if categoryObject.name?.lowercased() == category {
                observable.selectedCategory = categoryObject
            }
        }
    }

    func populateFrom(item: PocketCastsServer.DiscoverItem, region: String?, category: DiscoverCategory?) {
        observable.item = item
        observable.region = region
        view.setNeedsLayout()
    }

    init() {
        let observable = DiscoverItemObservable()
        self.observable = observable

        super.init(rootView: CategoriesSelectorView(discoverItemObservable: observable))
        sizingOptions =  [.intrinsicContentSize]
        view.backgroundColor = nil

        self.observable.$selectedCategory
            .delay(for: .milliseconds(20), scheduler: DispatchQueue.main)
            .sink { [weak self] category in
                guard let item = self?.observable.item else { return }
                self?.delegate?.showExpanded(item: item, category: category)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Constants.Notifications.discoverNavigateToCategory)
            .receive(on: OperationQueue.main)
            .sink { [unowned self] notification in
                guard let category = notification.object as? String else {
                    return
                }
                self.setCategory(category)
            }
            .store(in: &cancellables)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#if DEBUG

import SwiftUI

#Preview("Categories selector") {
    let section = CategoriesSelectorViewController()
    section.serverHandler = PreviewDiscoverServerHandler(categories: DiscoverPreviewData.categories())
    return DiscoverSectionPreview(
        section: section,
        item: DiscoverPreviewData.item(.categoriesSelector, title: "Categories")
    )
}

#Preview("Categories selector · popular only") {
    let section = CategoriesSelectorViewController()
    section.serverHandler = PreviewDiscoverServerHandler(categories: DiscoverPreviewData.categories())
    return DiscoverSectionPreview(
        section: section,
        item: DiscoverPreviewData.item(.categoriesSelector, title: "Categories", popular: [1, 3, 8, 12])
    )
}

#endif
