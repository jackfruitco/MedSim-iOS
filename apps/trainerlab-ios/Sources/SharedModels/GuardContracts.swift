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

/// Maps to backend `GuardStateOut` from the guard-state endpoint.
public struct SimulationGuardState: Codable, Equatable, Sendable {
    public let guardState: GuardState
    public let pauseReason: PauseReason?
    public let runtimeMinutesUsed: Int
    public let runtimeCapMinutes: Int?
    public let warnings: [GuardWarning]
    public let canResume: Bool
    public let denialReason: DenialReason?

    public init(
        guardState: GuardState,
        pauseReason: PauseReason? = nil,
        runtimeMinutesUsed: Int = 0,
        runtimeCapMinutes: Int? = nil,
        warnings: [GuardWarning] = [],
        canResume: Bool = false,
        denialReason: DenialReason? = nil
    ) {
        self.guardState = guardState
        self.pauseReason = pauseReason
        self.runtimeMinutesUsed = runtimeMinutesUsed
        self.runtimeCapMinutes = runtimeCapMinutes
        self.warnings = warnings
        self.canResume = canResume
        self.denialReason = denialReason
    }

    enum CodingKeys: String, CodingKey {
        case guardState = "guard_state"
        case pauseReason = "pause_reason"
        case runtimeMinutesUsed = "runtime_minutes_used"
        case runtimeCapMinutes = "runtime_cap_minutes"
        case warnings
        case canResume = "can_resume"
        case denialReason = "denial_reason"
    }
}

// MARK: - Computed Helpers

extension SimulationGuardState {
    /// Whether the simulation engine can progress (ticks, steer, etc.).
    public var isEngineRunnable: Bool {
        guardState == .active
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
    public var isResumablePause: Bool {
        canResume && !isTerminalPause
    }

    /// Whether chat message sending should be locked.
    public var shouldLockChatSending: Bool {
        !isEngineRunnable
    }

    /// Remaining runtime minutes, if a cap is configured.
    public var remainingMinutes: Int? {
        guard let cap = runtimeCapMinutes else { return nil }
        return max(0, cap - runtimeMinutesUsed)
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

    /// User-facing denial message, preferring backend-provided text.
    public var denialMessage: String? {
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

// MARK: - Heartbeat Response

public struct HeartbeatResponse: Codable, Sendable {
    public let success: Bool

    public init(success: Bool) {
        self.success = success
    }
}
