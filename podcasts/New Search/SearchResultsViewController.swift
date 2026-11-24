import Foundation
import SwiftUI
import PocketCastsUtils

protocol SearchResultsDelegate {
    func clearSearch()
    func performLocalSearch(searchTerm: String)
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void))
}

extension SearchResultsDelegate {
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {}
}

class SearchResultsViewController: UIHostingController<AnyView> {
    private let displaySearch = SearchVisibilityModel()
    private let searchHistoryModel = SearchHistoryModel.shared
    private let searchResults: SearchResultsModel
    private let networkNavigator: NetworkNavigator

    init(showLocalResults: Bool = false) {
        self.searchResults = SearchResultsModel(showLocalResults: showLocalResults)
        self.networkNavigator = NetworkNavigator()
        super.init(rootView: AnyView(
                    SearchView()
                        .setupDefaultEnvironment()
                        .environmentObject(searchResults)
                        .environmentObject(searchHistoryModel)
                        .environmentObject(networkNavigator)
                        .environmentObject(displaySearch))
        )

        networkNavigator.presenter = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func searchShown() {
    }

    func searchDismissed() {
    }
}

extension SearchResultsViewController: SearchResultsDelegate {
    func clearSearch() {
        displaySearch.isSearching = false
        searchResults.clearSearch()
    }

    func performLocalSearch(searchTerm: String) {
        displaySearch.isSearching = true
        searchResults.searchLocally(term: searchTerm)
    }

    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {
        displaySearch.isSearching = true
        if searchTerm.trim().isEmpty {
            completion()
        }

        if triggeredByTimer {
            searchResults.predictiveSearch(term: searchTerm)
        } else {
            searchResults.search(term: searchTerm)
        }

        if !triggeredByTimer, !searchTerm.trim().isEmpty {
            searchHistoryModel.add(searchTerm: searchTerm)
        }

        completion()
    }
}
