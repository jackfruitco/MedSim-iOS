import Sessions
import SharedModels
import XCTest

final class RunSessionReducerTests: XCTestCase {
    func testEventReceivedAppendsTimelineAndUpdatesCursor() {
        let event = EventEnvelope(
            eventID: "evt-1",
            eventType: SimulationEventType.simulationStatusUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: ["status": .string("running")],
        )

        let next = RunSessionReducer.reduce(
            state: RunSessionState(),
            action: .eventReceived(event),
        )

        XCTAssertEqual(next.timeline, [event])
        XCTAssertEqual(next.eventCursor, "evt-1")
    }

    func testTransportChangeUpdatesTransportState() {
        var state = RunSessionState()
        state = RunSessionReducer.reduce(state: state, action: .transportChanged(.polling))
        XCTAssertEqual(state.transportState, .polling)
    }

    func testConflictBannerCanBeSetAndCleared() {
        var state = RunSessionState()
        state = RunSessionReducer.reduce(state: state, action: .conflict("Conflict detected"))
        XCTAssertEqual(state.conflictBanner, "Conflict detected")
        state = RunSessionReducer.reduce(state: state, action: .clearConflict)
        XCTAssertNil(state.conflictBanner)
    }
}
