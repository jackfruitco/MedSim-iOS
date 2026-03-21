import Foundation
import SharedModels

public enum RunSessionReducerAction: Sendable {
    case sessionLoaded(TrainerSessionDTO)
    case transportChanged(RealtimeTransportState)
    case eventReceived(EventEnvelope)
    case pendingCommandCountChanged(Int)
    case conflict(String)
    case clearConflict
}

public enum RunSessionReducer {
    public static func reduce(state: RunSessionState, action: RunSessionReducerAction) -> RunSessionState {
        var next = state

        switch action {
        case let .sessionLoaded(session):
            next.session = session

        case let .transportChanged(transport):
            next.transportState = transport

        case let .eventReceived(event):
            next.timeline.append(event)
            next.eventCursor = event.eventID
            if next.timeline.count > 400 {
                next.timeline.removeFirst(next.timeline.count - 400)
            }
            let eventType = canonicalEventType(event.eventType)
            if eventType.hasPrefix("run."), let session = next.session {
                var changed = session
                if eventType == "run.started" || eventType == "run.resumed" {
                    changed = TrainerSessionDTO(
                        simulationID: session.simulationID,
                        status: .running,
                        scenarioSpec: session.scenarioSpec,
                        runtimeState: session.runtimeState,
                        initialDirectives: session.initialDirectives,
                        tickIntervalSeconds: session.tickIntervalSeconds,
                        runStartedAt: session.runStartedAt,
                        runPausedAt: nil,
                        runCompletedAt: session.runCompletedAt,
                        lastAITickAt: session.lastAITickAt,
                        createdAt: session.createdAt,
                        modifiedAt: session.modifiedAt,
                        terminalReasonCode: session.terminalReasonCode,
                        terminalReasonText: session.terminalReasonText
                    )
                }
                if eventType == "run.paused" {
                    changed = TrainerSessionDTO(
                        simulationID: session.simulationID,
                        status: .paused,
                        scenarioSpec: session.scenarioSpec,
                        runtimeState: session.runtimeState,
                        initialDirectives: session.initialDirectives,
                        tickIntervalSeconds: session.tickIntervalSeconds,
                        runStartedAt: session.runStartedAt,
                        runPausedAt: Date(),
                        runCompletedAt: session.runCompletedAt,
                        lastAITickAt: session.lastAITickAt,
                        createdAt: session.createdAt,
                        modifiedAt: session.modifiedAt,
                        terminalReasonCode: session.terminalReasonCode,
                        terminalReasonText: session.terminalReasonText
                    )
                }
                if eventType == "run.stopped" || eventType == "run.completed" {
                    changed = TrainerSessionDTO(
                        simulationID: session.simulationID,
                        status: .completed,
                        scenarioSpec: session.scenarioSpec,
                        runtimeState: session.runtimeState,
                        initialDirectives: session.initialDirectives,
                        tickIntervalSeconds: session.tickIntervalSeconds,
                        runStartedAt: session.runStartedAt,
                        runPausedAt: session.runPausedAt,
                        runCompletedAt: Date(),
                        lastAITickAt: session.lastAITickAt,
                        createdAt: session.createdAt,
                        modifiedAt: session.modifiedAt,
                        terminalReasonCode: session.terminalReasonCode,
                        terminalReasonText: session.terminalReasonText
                    )
                }
                next.session = changed
            }

        case let .pendingCommandCountChanged(count):
            next.pendingCommandCount = count

        case let .conflict(message):
            next.conflictBanner = message

        case .clearConflict:
            next.conflictBanner = nil
        }

        return next
    }

    private static func canonicalEventType(_ eventType: String) -> String {
        let lowered = eventType.lowercased()
        if lowered.hasPrefix("trainerlab.") {
            return String(lowered.dropFirst("trainerlab.".count))
        }
        return lowered
    }
}
