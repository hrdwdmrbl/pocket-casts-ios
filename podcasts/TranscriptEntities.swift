import AppIntents
import PocketCastsDataModel

struct TranscriptPodcastEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("transcript_intent_podcast", defaultValue: "Podcast"))
    static var defaultQuery = TranscriptPodcastQuery()

    let id: String
    @Property(title: LocalizedStringResource("transcript_intent_title", defaultValue: "Title")) var title: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(_ podcast: Podcast) {
        id = podcast.uuid
        title = podcast.title ?? ""
    }
}

struct TranscriptPodcastQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TranscriptPodcastEntity] {
        identifiers.compactMap { DataManager.shared.findPodcast(uuid: $0).map(TranscriptPodcastEntity.init) }
    }

    func entities(matching string: String) async throws -> [TranscriptPodcastEntity] {
        DataManager.shared.allPodcasts(includeUnsubscribed: false)
            .filter { $0.title?.localizedStandardContains(string) == true }
            .map(TranscriptPodcastEntity.init)
    }

    func suggestedEntities() async throws -> [TranscriptPodcastEntity] {
        DataManager.shared.allPodcastsOrderedByTitle().map(TranscriptPodcastEntity.init)
    }
}

struct TranscriptEpisodeEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("transcript_intent_episode", defaultValue: "Episode"))
    static var defaultQuery = TranscriptEpisodeQuery()

    let id: String
    let podcastUuid: String
    @Property(title: LocalizedStringResource("transcript_intent_title", defaultValue: "Title")) var title: String
    @Property(title: LocalizedStringResource("transcript_intent_podcast", defaultValue: "Podcast")) var podcastTitle: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)", subtitle: "\(podcastTitle)") }

    init(_ episode: TranscriptEpisode) {
        id = episode.uuid
        podcastUuid = episode.podcastUuid
        title = episode.title
        podcastTitle = episode.podcastTitle
    }
}

struct TranscriptEpisodeQuery: EntityStringQuery {
    @IntentParameterDependency<SearchTranscriptsIntent>(\.$podcast) var searchIntent

    func entities(for identifiers: [String]) async throws -> [TranscriptEpisodeEntity] {
        try identifiers.compactMap { try DataManager.shared.transcripts.episode(uuid: $0).map(TranscriptEpisodeEntity.init) }
    }

    func entities(matching string: String) async throws -> [TranscriptEpisodeEntity] {
        try DataManager.shared.transcripts.episodes(matching: string, podcastUuid: searchIntent?.podcast.id).map(TranscriptEpisodeEntity.init)
    }

    func suggestedEntities() async throws -> [TranscriptEpisodeEntity] {
        try DataManager.shared.transcripts.episodes(podcastUuid: searchIntent?.podcast.id).map(TranscriptEpisodeEntity.init)
    }
}

struct TranscriptPassageEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("transcript_intent_passage", defaultValue: "Transcript Passage"))
    static var defaultQuery = TranscriptPassageQuery()

    let id: String
    @Property(title: LocalizedStringResource("transcript_intent_episode", defaultValue: "Episode")) var episode: TranscriptEpisodeEntity
    @Property(title: LocalizedStringResource("transcript_intent_text", defaultValue: "Text")) var text: String
    @Property(title: LocalizedStringResource("transcript_intent_speaker", defaultValue: "Speaker")) var speaker: String?
    @Property(title: LocalizedStringResource("transcript_intent_start", defaultValue: "Start Time (seconds)")) var startTime: Double?
    @Property(title: LocalizedStringResource("transcript_intent_end", defaultValue: "End Time (seconds)")) var endTime: Double?

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(episode.title)", subtitle: "\(text)") }

    init(_ passage: TranscriptPassage, episode: TranscriptEpisode) {
        id = passage.id
        self.episode = TranscriptEpisodeEntity(episode)
        text = passage.text
        speaker = passage.speaker
        startTime = passage.startTime
        endTime = passage.endTime
    }
}

struct TranscriptPassageQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TranscriptPassageEntity] {
        let transcripts = DataManager.shared.transcripts
        return try identifiers.compactMap { id in
            guard let passage = try transcripts.passage(id: id),
                  let episode = try transcripts.episode(uuid: passage.episodeUuid) else { return nil }
            return TranscriptPassageEntity(passage, episode: episode)
        }
    }
}
