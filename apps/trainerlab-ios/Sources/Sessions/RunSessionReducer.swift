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

        case let .pendingCommandCountChanged(count):
            next.pendingCommandCount = count

        case let .conflict(message):
            next.conflictBanner = message

        case .clearConflict:
            next.conflictBanner = nil
        }

        return next
    }
}
