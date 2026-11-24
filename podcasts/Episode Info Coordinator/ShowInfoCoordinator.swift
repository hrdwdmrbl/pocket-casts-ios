import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

actor ShowInfoCoordinator: ShowInfoCoordinating {
    static let shared = ShowInfoCoordinator()

    private let dataRetriever: ShowInfoDataRetriever
    private let podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever
    private let dataManager: DataManager
    private let transcriptDataRetriever: TranscriptsDataRetriever

    private var requestingShowInfo: [String: Task<Episode.Metadata?, Error>] = [:]

    init(
        dataRetriever: ShowInfoDataRetriever = ShowInfoDataRetriever(),
        podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever = PodcastIndexChapterDataRetriever(),
        dataManager: DataManager = .shared,
        transcriptDataRetriever: TranscriptsDataRetriever = .shared
    ) {
        self.dataRetriever = dataRetriever
        self.podcastIndexChapterRetriever = podcastIndexChapterRetriever
        self.dataManager = dataManager
        self.transcriptDataRetriever = transcriptDataRetriever
    }

    func clearCache() async {
        let requests = Array(requestingShowInfo.values)
        for task in requests { task.cancel() }
        await dataRetriever.clearCache()
        await podcastIndexChapterRetriever.clearCache()
        await transcriptDataRetriever.clearCache()
        for task in requests { _ = await task.result }
        requestingShowInfo.removeAll()
    }

    func loadShowNotes(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> String {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.showNotes ?? CacheServerHandler.noShowNotesMessage
    }

    func loadEpisodeArtworkUrl(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> URL? {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.image.flatMap(URL.init(string:))
    }

    public func loadChapters(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> ([Episode.Metadata.EpisodeChapter]?, [PodcastIndexChapter]?) {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)

        if let podcastIndexChapterUrl = metadata?.chaptersUrl,
           let chapters = try? await podcastIndexChapterRetriever.loadChapters(podcastIndexChapterUrl) {
            return (nil, chapters.chapters)
        }

        if let chapters = metadata?.chapters, !chapters.isEmpty {
            return (chapters, nil)
        }

        return (nil, nil)
    }

    public func loadTranscriptsMetadata(podcastUuid: String, episodeUuid: String) async throws -> [Episode.Metadata.Transcript] {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.transcripts ?? []
    }

    @discardableResult
    func loadShowInfo(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> Episode.Metadata? {
        try await requestShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
    }

    @discardableResult
    func requestShowInfo(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> Episode.Metadata? {
        if let task = requestingShowInfo[episodeUuid] {
            return try await task.value
        }

        let task = Task<Episode.Metadata?, Error> { [weak self] in
            guard let self else { throw TaskError.nilSelf }

            do {
                let data = try await dataRetriever.loadEpisodeDataFromCache(for: podcastUuid, episodeUuid: episodeUuid)
                await setRequestingShowInfoToNil(for: episodeUuid)
                return await getShowInfo(for: data?.data(using: .utf8))
            } catch {
                await setRequestingShowInfoToNil(for: episodeUuid)
                throw error
            }
        }

        requestingShowInfo[episodeUuid] = task

        return try await task.value
    }

    private func setRequestingShowInfoToNil(for episodeUuid: String) {
        requestingShowInfo[episodeUuid] = nil
    }

    private func getShowInfo(for data: Data?) async -> Episode.Metadata? {
        guard let data else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Episode.Metadata.self, from: data)
        } catch {
            return nil
        }
    }
}
