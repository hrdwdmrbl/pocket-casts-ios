import SwiftUI
import PocketCastsServer
import PocketCastsDataModel
import PocketCastsUtils

class SearchResultsModel: ObservableObject {
    private let podcastSearch = PodcastSearchTask()
    private let predictiveSearch = PredictiveSearchTask()
    private let combinedSearch = CombinedSearchTask()

    @Published var isShowingPredictiveSearch = false
    @Published var isSearchingPredictive = false

    @Published var isSearchingForPodcasts = false

    @Published var podcastSearchError: Error?
    @Published var predictiveSearchError: Error?

    @Published var podcasts: [PodcastSearchResult] = []
    @Published var predictive: [PredictiveSearchResult] = []
    @Published var combinedResults: [CombinedSearchResultType] = []

    @Published var isShowingLocalResultsOnly = false
    @Published var resultsContainLocalPodcasts = false

    private(set) var currentSearchTerm: String = ""
    private(set) var currentPredictiveSearchTerm: String = ""
    private var latestSearchID = 0

    private let dataMangager: DataManager

    let showLocalResults: Bool

    init(showLocalResults: Bool = false,
         dataManager: DataManager = DataManager.shared) {
        self.dataMangager = dataManager
        self.showLocalResults = showLocalResults
    }

    var noResults: Bool {
        podcasts.isEmpty && combinedResults.isEmpty && (!isShowingPredictiveSearch || predictive.isEmpty)
    }

    /// The networks among ``combinedResults``, which the Networks filter and its rows are drawn from.
    var networks: [NetworkSearchResult] {
        combinedResults.compactMap {
            guard case .network(let network) = $0 else { return nil }
            return network
        }
    }

    func clearSearch() {
        podcasts = []
        combinedResults = []
        resultsContainLocalPodcasts = false
        currentSearchTerm = ""
    }

    func clearErrors() {
        podcastSearchError = nil
        predictiveSearchError = nil
    }

    @MainActor
    func predictiveSearch(term: String) {
        currentSearchTerm = term
        clearErrors()
        latestSearchID += 1

        guard !term.trim().isEmpty, !isTermAnURL(term) else {
            return
        }

        let searchID = latestSearchID
        Task {
            isSearchingPredictive = true
            do {
                let results = try await predictiveSearch.search(term: term)
                if searchID == latestSearchID {
                    show(predictiveResults: results)
                    currentPredictiveSearchTerm = term
                }
            } catch {
                if searchID == latestSearchID {
                    predictiveSearchError = error
                    isShowingPredictiveSearch = true
                    predictive = []
                }
            }
            isSearchingPredictive = false
        }
    }

    private func isTermAnURL(_ term: String) -> Bool {
        return term.lowercased().startsWith(string: "http://") || term.lowercased().startsWith(string: "https://")
    }

    @MainActor
    func search(term: String) {
        if !isTermAnURL(term) {
            combinedSearch(term: term)
            return
        }

        currentSearchTerm = term
        clearErrors()
        latestSearchID += 1

        if !isShowingLocalResultsOnly {
            clearSearch()
        }

        Task {
            isSearchingForPodcasts = true
            do {
                let results = try await podcastSearch.search(term: term)
                show(podcastResults: results)
            } catch {
                podcastSearchError = error
            }

            isSearchingForPodcasts = false
        }
    }

    @MainActor
    func combinedSearch(term: String) {
        currentSearchTerm = term
        clearErrors()
        latestSearchID += 1

        if !isShowingLocalResultsOnly {
            clearSearch()
        }

        Task {
            isSearchingForPodcasts = true
            do {
                let results = try await combinedSearch.search(term: term)
                showCombinedResults(results)
            } catch {
                isShowingPredictiveSearch = false
                podcastSearchError = error
            }

            isSearchingForPodcasts = false
        }
    }

    @MainActor
    func searchLocally(term searchTerm: String) {
        clearSearch()

        let allPodcasts = dataMangager.allPodcasts(includeUnsubscribed: false)

        var results = [PodcastSearchResult?]()
        for podcast in allPodcasts {
            guard let title = podcast.title else { continue }

            if title.localizedCaseInsensitiveContains(searchTerm) {
                results.append(PodcastSearchResult(from: podcast))
            } else if let author = podcast.author, author.localizedCaseInsensitiveContains(searchTerm) {
                results.append(PodcastSearchResult(from: podcast))
            }
        }

        self.podcasts = results.compactMap { $0 }

        resultsContainLocalPodcasts = true
        isShowingLocalResultsOnly = true
    }

    private func show(podcastResults: [PodcastSearchResult]) {
        isShowingPredictiveSearch = false
        if isShowingLocalResultsOnly {
            podcasts.append(contentsOf: podcastResults.filter { !podcasts.contains($0) })
            isShowingLocalResultsOnly = false
        } else {
            podcasts = podcastResults
        }
    }

    private func show(predictiveResults: [PredictiveSearchResult]) {
        isShowingPredictiveSearch = true
        predictive = predictiveResults
    }

    private func showCombinedResults(_ results: [CombinedSearchResultType]) {
        isShowingPredictiveSearch = false
        combinedResults = results
    }
}
