import Foundation

// MARK: - Guard State

/// Backend guard state representing the current enforcement status of a simulation session.
public enum GuardState: String, Codable, Sendable, CaseIterable {
    case active = "ACTIVE"
    case pausedInactivity = "PAUSED_INACTIVITY"
    case pausedRuntimeCap = "PAUSED_RUNTIME_CAP"
    case pausedManual = "PAUSED_MANUAL"
    case ended = "ENDED"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: value) ?? .unknown
    }
}

// MARK: - Pause Reason

public enum PauseReason: String, Codable, Sendable, CaseIterable {
    case runtimeCap = "RUNTIME_CAP"
    case inactivity = "INACTIVITY"
    case manual = "MANUAL"
    case wallClockExpiry = "WALL_CLOCK_EXPIRY"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: value) ?? .unknown
    }
}

// MARK: - Denial Reason

public enum DenialReason: String, Codable, Sendable, CaseIterable {
    case runtimeCapExceeded = "RUNTIME_CAP_EXCEEDED"
    case tokenLimitExceeded = "TOKEN_LIMIT_EXCEEDED"
    case inactivityPaused = "INACTIVITY_PAUSED"
    case sessionEnded = "SESSION_ENDED"
    case insufficientBudget = "INSUFFICIENT_BUDGET"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: value) ?? .unknown
    }
}

// MARK: - Guard Warning

public enum GuardWarning: String, Codable, Sendable, CaseIterable {
    case staleHeartbeat = "STALE_HEARTBEAT"
    case approachingRuntimeCap = "APPROACHING_RUNTIME_CAP"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: value) ?? .unknown
    }
}

// MARK: - Simulation Guard State DTO

/// Maps to backend `GuardStateOut` from the guard-state and heartbeat endpoints.
public struct SimulationGuardState: Codable, Equatable, Sendable {
    public let guardState: GuardState
    public let pauseReason: PauseReason?
    public let engineRunnable: Bool
    public let activeElapsedSeconds: Int
    public let runtimeCapSeconds: Int?
    public let wallClockExpiresAt: String?
    public let warnings: [GuardWarning]
    public let denialReason: DenialReason?
    public let denialMessage: String?

    public init(
        guardState: GuardState,
        pauseReason: PauseReason? = nil,
        engineRunnable: Bool = true,
        activeElapsedSeconds: Int = 0,
        runtimeCapSeconds: Int? = nil,
        wallClockExpiresAt: String? = nil,
        warnings: [GuardWarning] = [],
        denialReason: DenialReason? = nil,
        denialMessage: String? = nil
    ) {
        self.guardState = guardState
        self.pauseReason = pauseReason
        self.engineRunnable = engineRunnable
        self.activeElapsedSeconds = activeElapsedSeconds
        self.runtimeCapSeconds = runtimeCapSeconds
        self.wallClockExpiresAt = wallClockExpiresAt
        self.warnings = warnings
        self.denialReason = denialReason
        self.denialMessage = denialMessage
    }

    enum CodingKeys: String, CodingKey {
        case guardState = "guard_state"
        case pauseReason = "pause_reason"
        case engineRunnable = "engine_runnable"
        case activeElapsedSeconds = "active_elapsed_seconds"
        case runtimeCapSeconds = "runtime_cap_seconds"
        case wallClockExpiresAt = "wall_clock_expires_at"
        case warnings
        case denialReason = "denial_reason"
        case denialMessage = "denial_message"
    }
}

// MARK: - Computed Helpers

extension SimulationGuardState {
    /// Whether the simulation engine can progress (ticks, steer, etc.).
    /// Uses the backend-provided `engine_runnable` flag directly.
    public var isEngineRunnable: Bool {
        engineRunnable
    }

    /// Whether the simulation is in any paused state.
    public var isPaused: Bool {
        switch guardState {
        case .pausedInactivity, .pausedRuntimeCap, .pausedManual:
            true
        default:
            false
        }
    }

    /// Whether the pause is terminal — engine can never resume.
    public var isTerminalPause: Bool {
        guardState == .pausedRuntimeCap || guardState == .ended
    }

    /// Whether the user can resume from this pause state.
    /// Derived from guard state: non-terminal pauses are resumable.
    public var isResumablePause: Bool {
        isPaused && !isTerminalPause
    }

    /// Whether chat message sending should be locked.
    public var shouldLockChatSending: Bool {
        !isEngineRunnable
    }

    /// Remaining runtime in minutes, if a cap is configured.
    public var remainingMinutes: Int? {
        guard let cap = runtimeCapSeconds else { return nil }
        return max(0, (cap - activeElapsedSeconds) / 60)
    }

    /// User-facing warning message derived from backend warnings.
    public var warningMessage: String? {
        if warnings.contains(.approachingRuntimeCap), let remaining = remainingMinutes {
            return "Runtime limit approaching — \(remaining) min remaining"
        }
        if warnings.contains(.approachingRuntimeCap) {
            return "Approaching runtime limit"
        }
        if warnings.contains(.staleHeartbeat) {
            return "Connection may be stale"
        }
        return nil
    }

    /// User-facing message explaining the current pause state.
    public var pauseMessage: String? {
        switch guardState {
        case .pausedInactivity:
            return "Session paused due to inactivity"
        case .pausedRuntimeCap:
            return "Runtime limit reached — engine progression is no longer available"
        case .pausedManual:
            return "Session manually paused"
        case .ended:
            return "Session has ended"
        default:
            return nil
        }
    }

    /// User-facing denial message — prefers backend-provided text, falls back to per-reason defaults.
    public var userFacingDenialMessage: String? {
        if let denialMessage { return denialMessage }
        switch denialReason {
        case .runtimeCapExceeded:
            return "Runtime limit has been exceeded."
        case .tokenLimitExceeded:
            return "Token usage limit reached."
        case .inactivityPaused:
            return "Session is paused due to inactivity."
        case .sessionEnded:
            return "This session has ended."
        case .insufficientBudget:
            return "Insufficient budget remaining."
        default:
            return nil
        }
    }
}

// MARK: - Heartbeat Request

/// Payload for `POST /api/v1/simulations/{id}/heartbeat/`.
public struct HeartbeatRequest: Codable, Sendable {
    public let clientVisibility: String

    public init(clientVisibility: String = "unknown") {
        self.clientVisibility = clientVisibility
    }

    enum CodingKeys: String, CodingKey {
        case clientVisibility = "client_visibility"
    }
}
