import AppIntents
import PocketCastsDataModel
import UniformTypeIdentifiers

struct SearchTranscriptsIntent: AppIntent {
    static var title = LocalizedStringResource("transcript_intent_search_title", defaultValue: "Search Transcripts")
    static var description = IntentDescription(LocalizedStringResource("transcript_intent_search_description", defaultValue: "Search locally indexed transcripts, including archived episodes. Optionally choose a podcast or episode. Returns up to 50 matching passages with available speaker labels and timestamps. Open Pocket Casts to build and update the index."))
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var openAppWhenRun: Bool { false }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background] }

    @Parameter(title: LocalizedStringResource("transcript_intent_query", defaultValue: "Search Text")) var query: String
    @Parameter(title: LocalizedStringResource("transcript_intent_podcast", defaultValue: "Podcast")) var podcast: TranscriptPodcastEntity?
    @Parameter(title: LocalizedStringResource("transcript_intent_episode", defaultValue: "Episode")) var episode: TranscriptEpisodeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Search transcripts for \(\.$query)") {
            \.$podcast
            \.$episode
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[TranscriptPassageEntity]> & ProvidesDialog {
        guard query.rangeOfCharacter(from: .alphanumerics) != nil else { throw TranscriptIntentError.emptyQuery }
        if let episode {
            if let podcast, episode.podcastUuid != podcast.id { throw TranscriptIntentError.wrongPodcast }
            _ = try await TranscriptLibrary().transcript(episodeUuid: episode.id)
        }
        let transcripts = DataManager.shared.transcripts
        let passages = try transcripts.search(query, podcastUuid: podcast?.id, episodeUuid: episode?.id)
        let results = try passages.compactMap { passage -> TranscriptPassageEntity? in
            guard let episode = try transcripts.episode(uuid: passage.episodeUuid) else { return nil }
            return TranscriptPassageEntity(passage, episode: episode)
        }
        let coverage = try transcripts.coverage(podcastUuid: podcast?.id, episodeUuid: episode?.id)
        let message = coverage.unchecked > 0
            ? L10n.transcriptIntentSearchIncomplete(results.count, coverage.indexed, coverage.unchecked)
            : L10n.transcriptIntentSearchComplete(results.count, coverage.indexed)
        return .result(value: results, dialog: IntentDialog(stringLiteral: message))
    }
}

struct GetTranscriptIntent: AppIntent {
    static var title = LocalizedStringResource("transcript_intent_get_title", defaultValue: "Get Transcript")
    static var description = IntentDescription(LocalizedStringResource("transcript_intent_get_description", defaultValue: "Return an episode's full transcript as a text file, including available speaker labels and timestamps. Downloads the transcript if it is not already indexed."))
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var openAppWhenRun: Bool { false }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background] }

    @Parameter(title: LocalizedStringResource("transcript_intent_episode", defaultValue: "Episode")) var episode: TranscriptEpisodeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get transcript for \(\.$episode)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let text = try await TranscriptLibrary().transcript(episodeUuid: episode.id)
        let document = "\(episode.podcastTitle)\n\(episode.title)\n\n\(text)"
        return .result(value: IntentFile(data: Data(document.utf8), filename: "\(episode.id).txt", type: .plainText))
    }
}

enum TranscriptIntentError: LocalizedError {
    case emptyQuery
    case wrongPodcast

    var errorDescription: String? {
        switch self {
        case .emptyQuery: L10n.transcriptIntentEmptyQuery
        case .wrongPodcast: L10n.transcriptIntentWrongPodcast
        }
    }
}
