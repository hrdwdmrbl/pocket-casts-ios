import Foundation
import PocketCastsDataModel
import PocketCastsUtils

actor TranscriptLibrary {
    private let dataManager: DataManager
    private let load: (TranscriptEpisode) async throws -> TranscriptModel

    init(dataManager: DataManager = .shared, load: @escaping (TranscriptEpisode) async throws -> TranscriptModel = { episode in
        try await TranscriptManager(episodeUUID: episode.uuid, podcastUUID: episode.podcastUuid).loadTranscript()
    }) {
        self.dataManager = dataManager
        self.load = load
    }

    func transcript(episodeUuid: String) async throws -> String {
        guard let episode = try dataManager.transcripts.episode(uuid: episodeUuid) else {
            throw TranscriptError.notAvailable
        }
        if let text = try dataManager.transcripts.text(episodeUuid: episodeUuid) { return text }
        let model = try await load(episode)
        try Task.checkCancellation()
        return try save(model, episode: episode)
    }

    func indexLibrary() async {
        do {
            for episode in try dataManager.transcripts.episodesToIndex() {
                try Task.checkCancellation()
                do {
                    let model = try await load(episode)
                    try Task.checkCancellation()
                    try save(model, episode: episode)
                } catch TranscriptError.notAvailable {
                    try Task.checkCancellation()
                    try dataManager.transcripts.save(episodeUuid: episode.uuid, text: nil, passages: [])
                } catch {
                    try Task.checkCancellation()
                    // Failed requests remain unchecked and are retried on the next indexing pass.
                    FileLog.shared.addMessage("Transcript indexing failed for \(episode.uuid): \(error)")
                }
            }
        } catch is CancellationError {
            // Indexing resumes from the saved episodes when the app becomes active again.
        } catch {
            FileLog.shared.addMessage("Transcript indexing failed: \(error)")
        }
    }

    @discardableResult
    private func save(_ model: TranscriptModel, episode: TranscriptEpisode) throws -> String {
        let passages = model.searchPassages(episodeUuid: episode.uuid)
        let text: String = passages.map { passage in
            let time = passage.startTime.map { "[\(TimeFormatter.shared.multipleUnitFormattedShortTime(time: $0))] " } ?? ""
            let speaker = passage.speaker.map { "\($0): " } ?? ""
            return "\(time)\(speaker)\(passage.text)"
        }.joined(separator: "\n\n")
        try dataManager.transcripts.save(episodeUuid: episode.uuid, text: text, passages: passages)
        return text
    }
}

extension TranscriptModel {
    /// Group adjacent cues into short passages so a search can match across caption boundaries.
    func searchPassages(episodeUuid: String) -> [TranscriptPassage] {
        if cues.isEmpty {
            let words = attributedText.string.split(whereSeparator: \.isWhitespace)
            return stride(from: 0, to: words.count, by: 150).enumerated().map { index, start in
                TranscriptPassage(id: "\(episodeUuid)/\(index)", episodeUuid: episodeUuid,
                                  text: words[start..<min(start + 150, words.count)].joined(separator: " "),
                                  speaker: nil, startTime: nil, endTime: nil)
            }
        }

        var speakers: [(location: Int, name: String)] = []
        attributedText.enumerateAttribute(.transcriptSpeaker, in: NSRange(location: 0, length: attributedText.length)) { value, range, _ in
            if let name = value as? String { speakers.append((range.location, name)) }
        }
        var speakerIndex = 0
        var speaker: String?
        var passages: [TranscriptPassage] = []
        for cue in cues {
            while speakerIndex < speakers.count && speakers[speakerIndex].location <= cue.characterRange.location {
                speaker = speakers[speakerIndex].name
                speakerIndex += 1
            }
            let text = attributedText.attributedSubstring(from: cue.characterRange).string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let previous = passages.last, previous.speaker == speaker,
               let start = previous.startTime, let end = previous.endTime,
               cue.endTime - start <= 30, cue.startTime - end <= 2 {
                passages[passages.count - 1] = TranscriptPassage(id: previous.id, episodeUuid: episodeUuid,
                    text: previous.text + " " + text, speaker: speaker, startTime: start, endTime: cue.endTime)
            } else {
                passages.append(TranscriptPassage(id: "\(episodeUuid)/\(passages.count)", episodeUuid: episodeUuid,
                    text: text, speaker: speaker, startTime: cue.startTime, endTime: cue.endTime))
            }
        }
        return passages
    }
}
