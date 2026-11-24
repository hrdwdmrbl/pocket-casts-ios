import SwiftUI
import Combine
import PocketCastsServer
import PocketCastsDataModel
import PocketCastsUtils

@MainActor
final class LocalSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var episodes: [EpisodeSearchResult] = []
    @Published private(set) var selectedPodcast: Podcast?
    @Published private(set) var isEpisodeSearchInFlight = false
    @Published private(set) var addedEpisodeCount = 0
    @Published private(set) var searchResultsPodcasts: [PodcastSearchResult] = []
    @Published private(set) var disableLibraryAnimation = false
    @Published private(set) var defaultLibraryItems: [PodcastSearchResult] = []
    @Published private(set) var isLoadingDefaultLibrary = false
    @Published private(set) var isLoadingPlaylistEpisodes = false

    let playlist: EpisodeFilter

    private var cancellables = Set<AnyCancellable>()
    private var searchResultsModel: SearchResultsModel?
    private var episodeCoordinator: LocalSearchCoordinator?
    private var hasAppeared = false

    private struct PodcastSearchState {
        let term: String
        let results: [PodcastSearchResult]
    }
    private var previousPodcastSearchState: PodcastSearchState?

    init(playlist: EpisodeFilter) {
        self.playlist = playlist

        $searchText
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.handleSearchTextChange(newValue)
            }
            .store(in: &cancellables)
    }

    var searchMode: SearchMode {
        selectedPodcast == nil ? .podcasts : .episodes
    }

    var podcastListMode: PodcastListMode {
        if !trimmedSearchText.isEmpty || previousPodcastSearchState != nil {
            return .search
        }
        return .library
    }

    var rootListMode: PodcastListMode {
        if !trimmedSearchText.isEmpty || previousPodcastSearchState != nil {
            return .search
        }
        return .library
    }

    private func loadDefaultLibraryItems() async {
        await MainActor.run {
            self.isLoadingDefaultLibrary = true
        }

        let items = await Task.detached {
            let sortOrder = Settings.librarySortOrder
            let items = HomeGridDataHelper.gridItems(orderedBy: sortOrder)
            return items.compactMap { PodcastSearchResult(from: $0.podcast) }
        }.value

        await MainActor.run {
            self.defaultLibraryItems = items
            self.isLoadingDefaultLibrary = false
        }
    }

    var isPodcastListLoading: Bool {
        switch podcastListMode {
        case .library:
            return isLoadingDefaultLibrary
        case .search:
            return false // Search results use the searchResultsModel which handles its own loading
        }
    }

    var navigationTitle: String {
        let name = playlist.playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard addedEpisodeCount > 0 else {
            return L10n.playlistAddToTitle(name)
        }

        if addedEpisodeCount == 1 {
            let format = L10n.localizedFormat("playlist_episode_added_title", "Localizable", "1 episode added to \"%@\"")
            return String(format: format, locale: Locale.current, name)
        } else {
            let format = L10n.localizedFormat("playlist_episodes_added_title", "Localizable", "%1$@ episodes added to \"%2$@\"")
            return String(format: format, locale: Locale.current, addedEpisodeCount.localized(), name)
        }
    }

    func onAppear(searchResultsModel: SearchResultsModel) {
        configureSearchResultsIfNeeded(searchResultsModel)
        guard !hasAppeared else { return }
        hasAppeared = true

        Task {
            await loadDefaultLibraryItems()
            await loadPodcastsIfNeeded()
            await refreshPlaylistEpisodes()
        }
    }

    func onDisappear() {
        episodeCoordinator?.cancelPendingSearch()
    }

    func podcast(from result: PodcastSearchResult) -> Podcast? {
        guard result.kind == .podcast,
              let podcast = DataManager.shared.findPodcast(uuid: result.uuid) else {
            return nil
        }
        return podcast
    }

    func beginEpisodeMode(with podcast: Podcast) {
        previousPodcastSearchState = currentSearchState()
        selectedPodcast = podcast
        searchText = ""

        episodeCoordinator?.preloadEpisodes(for: selectedPodcast)

        Task {
            await episodeCoordinator?.refreshPlaylistEpisodes()
        }
    }

    func clearSelectedPodcast() {
        let searchState = previousPodcastSearchState
        selectedPodcast = nil

        Task {if let searchState, !searchState.term.isEmpty {
            searchResultsPodcasts = searchState.results
            if searchText != searchState.term {
                searchText = searchState.term
            } else {
                await filterPodcasts(using: searchState.term)
            }
        } else {
            if !searchText.isEmpty {
                searchText = ""
            }
            await filterPodcasts(using: "")
        }

        await MainActor.run {
            self.episodeCoordinator?.clearResults()
        }
        previousPodcastSearchState = nil
        }
    }

    func triggerImmediateSearch() {
        guard searchMode == .episodes,
              let coordinator = episodeCoordinator else { return }

        let trimmed = trimmedSearchText
        guard let podcastUuid = selectedPodcast?.uuid, trimmed.count >= 2 else {
            coordinator.clearResults()
            coordinator.preloadEpisodes(for: selectedPodcast)
            return
        }

        coordinator.triggerImmediateSearch(for: trimmed, podcastUuid: podcastUuid)
    }

    func handleAddEpisode(_ searchResult: EpisodeSearchResult) {
        episodeCoordinator?.handleAddEpisode(searchResult)
    }

    private func configureSearchResultsIfNeeded(_ searchResultsModel: SearchResultsModel) {
        guard self.searchResultsModel !== searchResultsModel else { return }
        self.searchResultsModel = searchResultsModel
        configureEpisodeCoordinatorIfNeeded()

        searchResultsModel.$podcasts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                guard let self else { return }
                self.searchResultsPodcasts = results.filter { result in
                    (result.isLocal ?? true)
                }
            }
            .store(in: &cancellables)
    }

    private func configureEpisodeCoordinatorIfNeeded() {
        guard episodeCoordinator == nil else { return }

        let coordinator = LocalSearchCoordinator(
            playlist: playlist
        )

        coordinator.$episodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.episodes = $0 }
            .store(in: &cancellables)

        coordinator.$isSearchInFlight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isEpisodeSearchInFlight = $0 }
            .store(in: &cancellables)

        coordinator.$addedEpisodeCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.addedEpisodeCount = $0 }
            .store(in: &cancellables)

        episodeCoordinator = coordinator

        Task {
            await episodeCoordinator?.refreshPlaylistEpisodes()
            episodeCoordinator?.preloadEpisodes(for: selectedPodcast)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadPodcastsIfNeeded() async {
        await filterPodcasts(using: searchText)
    }

    private func refreshPlaylistEpisodes() async {
        isLoadingPlaylistEpisodes = true
        await episodeCoordinator?.refreshPlaylistEpisodes()
        isLoadingPlaylistEpisodes = false
    }

    private func handleSearchTextChange(_ newValue: String) {
        switch searchMode {
        case .podcasts:
            Task {
                await filterPodcasts(using: newValue)
            }
        case .episodes:
            scheduleEpisodeSearch(with: newValue)
        }
    }

    private func filterPodcasts(using term: String, disableAnimationsWhenClearing: Bool = true) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let searchResultsModel else { return }

        if trimmed.isEmpty {
            if disableAnimationsWhenClearing {
                disableLibraryAnimation = true
            }
            let transaction = disableAnimationsWhenClearing ? Transaction(animation: nil) : Transaction()
            withTransaction(transaction) {
                searchResultsModel.clearSearch()
            }
            if disableAnimationsWhenClearing {
                DispatchQueue.main.async { [weak self] in
                    self?.disableLibraryAnimation = false
                }
            }
        } else {
            searchResultsModel.searchLocally(term: trimmed)
        }
    }

    private func scheduleEpisodeSearch(with term: String) {
        guard let coordinator = episodeCoordinator else { return }

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let podcastUuid = selectedPodcast?.uuid, trimmed.count >= 2 else {
            coordinator.clearResults()
            coordinator.preloadEpisodes(for: selectedPodcast)
            return
        }

        coordinator.scheduleSearch(for: trimmed, podcastUuid: podcastUuid)
    }
}

extension EpisodeSearchResult {
    init(episode: Episode, dataManager: DataManager = DataManager.shared) {
        let publishedDate = episode.publishedDate ?? episode.addedDate ?? Date()
        let duration = episode.duration > 0 ? episode.duration : nil
        let podcastTitle = episode.parentPodcast(dataManager: dataManager)?.title ?? ""
        let state: EpisodeSearchResult.State = episode.wasDeleted ? .unavailable : episode.archived ? .archived : .normal

        self.init(uuid: episode.uuid, title: episode.displayableTitle(), publishedDate: publishedDate, state: state, duration: duration, podcastUuid: episode.podcastUuid, podcastTitle: podcastTitle, hasVideo: episode.videoPodcast())
    }

    init(listEpisode: ListEpisode, dataManager: DataManager = DataManager.shared) {
        self.init(episode: listEpisode.episode, dataManager: dataManager)
    }
}

extension LocalSearchViewModel {
    enum SearchMode {
        case podcasts
        case episodes
    }

    private func currentSearchState() -> PodcastSearchState? {
        let trimmed = trimmedSearchText
        guard !trimmed.isEmpty else { return nil }
        return PodcastSearchState(term: trimmed, results: searchResultsPodcasts)
    }
}
