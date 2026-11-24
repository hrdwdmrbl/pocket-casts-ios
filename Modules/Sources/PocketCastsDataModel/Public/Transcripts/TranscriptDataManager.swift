import Foundation
import GRDB

public struct TranscriptEpisode: Decodable, FetchableRecord, Sendable {
    public let uuid: String
    public let title: String
    public let podcastUuid: String
    public let podcastTitle: String
}

public struct TranscriptPassage: Decodable, FetchableRecord, Sendable {
    public let id: String
    public let episodeUuid: String
    public let text: String
    public let speaker: String?
    public let startTime: Double?
    public let endTime: Double?

    public init(id: String, episodeUuid: String, text: String, speaker: String?, startTime: Double?, endTime: Double?) {
        self.id = id
        self.episodeUuid = episodeUuid
        self.text = text
        self.speaker = speaker
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct TranscriptCoverage: Decodable, FetchableRecord {
    public let total: Int
    public let indexed: Int
    public let unchecked: Int
}

public struct TranscriptDataManager {
    private let dbQueue: GRDBQueue

    init(dbQueue: GRDBQueue) {
        self.dbQueue = dbQueue
    }

    private static let library = """
        FROM SJEpisode e JOIN SJPodcast p ON p.uuid = e.podcastUuid
        WHERE e.wasDeleted = 0 AND p.subscribed = 1 AND p.wasDeleted = 0
        """
    private static let episodeColumns = """
        e.uuid, COALESCE(e.title, '') AS title, e.podcastUuid, COALESCE(p.title, '') AS podcastTitle
        """

    public func episodes(matching title: String = "", podcastUuid: String? = nil) throws -> [TranscriptEpisode] {
        try dbQueue.dbPool.read { db in
            try TranscriptEpisode.fetchAll(db, sql: """
                SELECT \(Self.episodeColumns) \(Self.library)
                AND (? IS NULL OR e.podcastUuid = ?) AND instr(lower(COALESCE(e.title, '')), lower(?)) > 0
                ORDER BY e.publishedDate DESC, e.uuid LIMIT 50
                """, arguments: [podcastUuid, podcastUuid, title])
        }
    }

    public func episode(uuid: String) throws -> TranscriptEpisode? {
        try dbQueue.dbPool.read { db in
            try TranscriptEpisode.fetchOne(db, sql: """
                SELECT \(Self.episodeColumns) \(Self.library) AND e.uuid = ?
                """, arguments: [uuid])
        }
    }

    public func episodesToIndex() throws -> [TranscriptEpisode] {
        try dbQueue.dbPool.read { db in
            try TranscriptEpisode.fetchAll(db, sql: """
                SELECT \(Self.episodeColumns) \(Self.library)
                AND NOT EXISTS (
                    SELECT 1 FROM Transcript t WHERE t.episodeUuid = e.uuid
                    AND (t.text IS NOT NULL OR t.checkedAt > ?)
                )
                ORDER BY e.publishedDate DESC, e.uuid
                """, arguments: [Date().addingTimeInterval(-86400).timeIntervalSince1970])
        }
    }

    public func text(episodeUuid: String) throws -> String? {
        try dbQueue.dbPool.read { db in
            try String.fetchOne(db, sql: """
                SELECT t.text FROM Transcript t WHERE t.episodeUuid = ?
                AND EXISTS (SELECT 1 \(Self.library) AND e.uuid = t.episodeUuid)
                """, arguments: [episodeUuid])
        }
    }

    /// A nil transcript records a successful check that found no transcript.
    public func save(episodeUuid: String, text: String?, passages: [TranscriptPassage]) throws {
        try dbQueue.dbPool.write { db in
            // The episode may have been removed while its transcript was downloading.
            guard try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 \(Self.library) AND e.uuid = ?)", arguments: [episodeUuid]) == true else { return }
            try db.execute(sql: "DELETE FROM TranscriptPassage WHERE episodeUuid = ?", arguments: [episodeUuid])
            try db.execute(sql: """
                INSERT INTO Transcript (episodeUuid, text, checkedAt) VALUES (?, ?, ?)
                ON CONFLICT(episodeUuid) DO UPDATE SET text = excluded.text, checkedAt = excluded.checkedAt
                """, arguments: [episodeUuid, text, Date().timeIntervalSince1970])
            for passage in passages {
                try db.execute(sql: """
                    INSERT INTO TranscriptPassage (id, episodeUuid, text, speaker, startTime, endTime)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [passage.id, episodeUuid, passage.text, passage.speaker, passage.startTime, passage.endTime])
            }
        }
    }

    public func search(_ query: String, podcastUuid: String? = nil, episodeUuid: String? = nil) throws -> [TranscriptPassage] {
        guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else { return [] }
        return try dbQueue.dbPool.read { db in
            try TranscriptPassage.fetchAll(db, sql: """
                SELECT * FROM TranscriptPassage
                WHERE TranscriptPassage MATCH ?
                AND EXISTS (SELECT 1 \(Self.library) AND e.uuid = TranscriptPassage.episodeUuid
                    AND (? IS NULL OR e.podcastUuid = ?) AND (? IS NULL OR e.uuid = ?))
                ORDER BY rank, id LIMIT 50
                """, arguments: [pattern, podcastUuid, podcastUuid, episodeUuid, episodeUuid])
        }
    }

    public func passage(id: String) throws -> TranscriptPassage? {
        try dbQueue.dbPool.read { db in
            try TranscriptPassage.fetchOne(db, sql: """
                SELECT * FROM TranscriptPassage WHERE id = ?
                AND EXISTS (SELECT 1 \(Self.library) AND e.uuid = TranscriptPassage.episodeUuid)
                """, arguments: [id])
        }
    }

    public func coverage(podcastUuid: String? = nil, episodeUuid: String? = nil) throws -> TranscriptCoverage {
        try dbQueue.dbPool.read { db in
            try TranscriptCoverage.fetchOne(db, sql: """
                SELECT COUNT(*) AS total,
                    COUNT((SELECT 1 FROM Transcript t WHERE t.episodeUuid = e.uuid AND t.text IS NOT NULL)) AS indexed,
                    COUNT(*) - COUNT((SELECT 1 FROM Transcript t WHERE t.episodeUuid = e.uuid)) AS unchecked
                \(Self.library) AND (? IS NULL OR e.podcastUuid = ?) AND (? IS NULL OR e.uuid = ?)
                """, arguments: [podcastUuid, podcastUuid, episodeUuid, episodeUuid])!
        }
    }

    static func createTables(in db: PCDatabase) throws {
        try db.executeUpdate("""
            CREATE TABLE Transcript (episodeUuid TEXT PRIMARY KEY NOT NULL, text TEXT, checkedAt REAL NOT NULL);
            """, values: nil)
        try db.executeUpdate("""
            CREATE VIRTUAL TABLE TranscriptPassage USING fts5(
                id UNINDEXED, episodeUuid UNINDEXED, text, speaker UNINDEXED, startTime UNINDEXED, endTime UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 2'
            );
            """, values: nil)
        try db.executeUpdate("""
            CREATE TRIGGER transcript_episode_deleted AFTER DELETE ON SJEpisode BEGIN
                DELETE FROM Transcript WHERE episodeUuid = old.uuid;
                DELETE FROM TranscriptPassage WHERE episodeUuid = old.uuid;
            END;
            """, values: nil)
    }
}

extension DataManager {
    public var transcripts: TranscriptDataManager { TranscriptDataManager(dbQueue: dbQueue) }
}
