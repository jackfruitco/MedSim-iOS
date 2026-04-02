import Foundation

public struct GuardSignal: Decodable, Equatable, Sendable {
    public let code: String
    public let severity: String
    public let title: String?
    public let message: String
    public let resumable: Bool?
    public let terminal: Bool?
    public let expiresInSeconds: Int?
    public let metadata: [String: JSONValue]?

    public init(
        code: String,
        severity: String,
        title: String?,
        message: String,
        resumable: Bool?,
        terminal: Bool?,
        expiresInSeconds: Int?,
        metadata: [String: JSONValue]?,
    ) {
        self.code = code
        self.severity = severity
        self.title = title
        self.message = message
        self.resumable = resumable
        self.terminal = terminal
        self.expiresInSeconds = expiresInSeconds
        self.metadata = metadata
    }

    public var isTerminal: Bool { terminal ?? false }
    public var isResumable: Bool { resumable ?? false }
    public var displayTitle: String { title ?? "Notice" }

    enum CodingKeys: String, CodingKey {
        case code
        case severity
        case title
        case message
        case resumable
        case terminal
        case expiresInSeconds = "expires_in_seconds"
        case metadata
    }
}

public struct GuardStateDTO: Decodable, Equatable, Sendable {
    public let guardState: String
    public let guardReason: String
    public let engineRunnable: Bool
    public let activeElapsedSeconds: Int
    public let runtimeCapSeconds: Int?
    public let wallClockExpiresAt: String?
    public let warnings: [GuardSignal]
    public let denial: GuardSignal?

    public init(
        guardState: String,
        guardReason: String,
        engineRunnable: Bool,
        activeElapsedSeconds: Int,
        runtimeCapSeconds: Int?,
        wallClockExpiresAt: String?,
        warnings: [GuardSignal],
        denial: GuardSignal?,
    ) {
        self.guardState = guardState
        self.guardReason = guardReason
        self.engineRunnable = engineRunnable
        self.activeElapsedSeconds = activeElapsedSeconds
        self.runtimeCapSeconds = runtimeCapSeconds
        self.wallClockExpiresAt = wallClockExpiresAt
        self.warnings = warnings
        self.denial = denial
    }

    public var isEngineBlocked: Bool { !engineRunnable }
    public var primaryDenial: GuardSignal? { denial }

    enum CodingKeys: String, CodingKey {
        case guardState = "guard_state"
        case guardReason = "guard_reason"
        case engineRunnable = "engine_runnable"
        case activeElapsedSeconds = "active_elapsed_seconds"
        case runtimeCapSeconds = "runtime_cap_seconds"
        case wallClockExpiresAt = "wall_clock_expires_at"
        case warnings
        case denial
    }
}

public struct GuardDeniedPayload: Decodable, Sendable {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    public let guardDenial: GuardSignal

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case status
        case detail
        case guardDenial = "guard_denial"
    }
}
