import CryptoKit
import Foundation
import GRDB

public enum PendingAckState: String, Codable, Sendable {
    case pending
    case failed
}

public struct PendingCommandEnvelope: Codable, FetchableRecord, MutablePersistableRecord, Equatable, Identifiable, Sendable {
    public static let databaseTableName = "pending_commands"

    public var localID: Int64?
    public var idempotencyKey: String
    public var endpoint: String
    public var method: String
    public var bodyBase64: String?
    public var bodyHash: String
    public var createdAt: Date
    public var retryCount: Int
    public var maxRetries: Int
    public var lastError: String?
    public var nextRetryAt: Date
    public var ackState: PendingAckState

    public var id: String { idempotencyKey }

    public init(
        localID: Int64? = nil,
        idempotencyKey: String,
        endpoint: String,
        method: String,
        bodyBase64: String?,
        bodyHash: String,
        createdAt: Date,
        retryCount: Int = 0,
        maxRetries: Int = 10,
        lastError: String? = nil,
        nextRetryAt: Date,
        ackState: PendingAckState = .pending
    ) {
        self.localID = localID
        self.idempotencyKey = idempotencyKey
        self.endpoint = endpoint
        self.method = method
        self.bodyBase64 = bodyBase64
        self.bodyHash = bodyHash
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.ackState = ackState
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        localID = inserted.rowID
    }

    enum CodingKeys: String, CodingKey {
        case localID = "local_id"
        case idempotencyKey = "idempotency_key"
        case endpoint
        case method
        case bodyBase64 = "body_base64"
        case bodyHash = "body_hash"
        case createdAt = "created_at"
        case retryCount = "retry_count"
        case maxRetries = "max_retries"
        case lastError = "last_error"
        case nextRetryAt = "next_retry_at"
        case ackState = "ack_state"
    }
}

public enum CommandQueueStoreError: Error {
    case invalidDatabasePath
}

public protocol CommandQueueStoreProtocol: Sendable {
    func enqueue(_ envelope: PendingCommandEnvelope) async throws
    func markAcked(idempotencyKey: String) async throws
    func markFailed(idempotencyKey: String, error: String, nextRetryAt: Date) async throws
    func nextRetryBatch(limit: Int, now: Date) async throws -> [PendingCommandEnvelope]
    func pendingCount() async throws -> Int
    /// Deletes commands that have exceeded their max retry count. Returns the number of rows removed.
    func purgeAbandoned() async throws -> Int
}

public actor GRDBCommandQueueStore: CommandQueueStoreProtocol {
    private let dbQueue: DatabaseQueue

    public init(fileURL: URL) throws {
        guard !fileURL.path.isEmpty else {
            throw CommandQueueStoreError.invalidDatabasePath
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: fileURL.path)
        try Self.makeMigrator().migrate(dbQueue)
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("create_pending_commands") { db in
            try db.create(table: PendingCommandEnvelope.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("local_id")
                table.column("idempotency_key", .text).notNull().unique()
                table.column("endpoint", .text).notNull()
                table.column("method", .text).notNull()
                table.column("body_base64", .text)
                table.column("body_hash", .text).notNull()
                table.column("created_at", .datetime).notNull()
                table.column("retry_count", .integer).notNull().defaults(to: 0)
                table.column("last_error", .text)
                table.column("next_retry_at", .datetime).notNull()
                table.column("ack_state", .text).notNull()
            }
        }
        migrator.registerMigration("add_max_retries") { db in
            try db.alter(table: PendingCommandEnvelope.databaseTableName) { table in
                table.add(column: "max_retries", .integer).notNull().defaults(to: 10)
            }
        }
        migrator.registerMigration("migrate_simulation_first_endpoints") { db in
            try db.execute(sql: """
                UPDATE pending_commands
                SET endpoint = REPLACE(endpoint, '/api/v1/simulations/', '/api/v1/trainerlab/simulations/')
                WHERE endpoint LIKE '/api/v1/simulations/%/adjust/%'
            """)
            try db.execute(sql: """
                UPDATE pending_commands
                SET endpoint = '/api/v1/trainerlab/simulations/'
                WHERE endpoint = '/api/v1/trainerlab/sessions/'
            """)
            try db.execute(sql: """
                DELETE FROM pending_commands
                WHERE endpoint LIKE '/api/v1/trainerlab/sessions/%'
            """)
        }
        return migrator
    }

    public func enqueue(_ envelope: PendingCommandEnvelope) async throws {
        try await dbQueue.write { db in
            if var existing = try PendingCommandEnvelope
                .filter(Column("idempotency_key") == envelope.idempotencyKey)
                .fetchOne(db)
            {
                existing.endpoint = envelope.endpoint
                existing.method = envelope.method
                existing.bodyBase64 = envelope.bodyBase64
                existing.bodyHash = envelope.bodyHash
                existing.nextRetryAt = envelope.nextRetryAt
                existing.ackState = .pending
                try existing.update(db)
            } else {
                var mutable = envelope
                try mutable.insert(db)
            }
        }
    }

    public func markAcked(idempotencyKey: String) async throws {
        try await dbQueue.write { db in
            _ = try PendingCommandEnvelope
                .filter(Column("idempotency_key") == idempotencyKey)
                .deleteAll(db)
        }
    }

    public func markFailed(idempotencyKey: String, error: String, nextRetryAt: Date) async throws {
        try await dbQueue.write { db in
            if var existing = try PendingCommandEnvelope
                .filter(Column("idempotency_key") == idempotencyKey)
                .fetchOne(db)
            {
                existing.retryCount += 1
                existing.lastError = error
                existing.nextRetryAt = nextRetryAt
                existing.ackState = .failed
                try existing.update(db)
            }
        }
    }

    public func nextRetryBatch(limit: Int, now: Date) async throws -> [PendingCommandEnvelope] {
        try await dbQueue.read { db in
            try PendingCommandEnvelope
                .filter(
                    (Column("ack_state") != PendingAckState.pending.rawValue || Column("next_retry_at") <= now)
                    && Column("retry_count") < Column("max_retries")
                )
                .order(Column("next_retry_at").asc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func pendingCount() async throws -> Int {
        try await dbQueue.read { db in
            try PendingCommandEnvelope.fetchCount(db)
        }
    }

    public func purgeAbandoned() async throws -> Int {
        try await dbQueue.write { db in
            try PendingCommandEnvelope
                .filter(Column("retry_count") >= Column("max_retries"))
                .deleteAll(db)
        }
    }
}

public enum CommandEnvelopeBuilder {
    public static func make(
        endpoint: String,
        method: String,
        body: Data?
    ) -> PendingCommandEnvelope {
        let now = Date()
        let key = "ios.\(UUID().uuidString.lowercased())"
        return PendingCommandEnvelope(
            idempotencyKey: key,
            endpoint: endpoint,
            method: method,
            bodyBase64: body?.base64EncodedString(),
            bodyHash: sha256Hex(body ?? Data()),
            createdAt: now,
            retryCount: 0,
            lastError: nil,
            nextRetryAt: now,
            ackState: .pending
        )
    }

    public static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
