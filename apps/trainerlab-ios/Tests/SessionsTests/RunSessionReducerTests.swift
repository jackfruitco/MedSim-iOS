import Sessions
import SharedModels
import XCTest

final class RunSessionReducerTests: XCTestCase {
    func testRunLifecycleEventsUpdateSessionStatus() {
        let session = TrainerSessionDTO(
            simulationID: 10,
            status: .seeded,
            scenarioSpec: [:],
            runtimeState: [:],
            initialDirectives: nil,
            tickIntervalSeconds: 10,
            runStartedAt: nil,
            runPausedAt: nil,
            runCompletedAt: nil,
            lastAITickAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
        )

        var state = RunSessionReducer.reduce(state: RunSessionState(), action: .sessionLoaded(session))
        XCTAssertEqual(state.session?.status, .seeded)

        state = RunSessionReducer.reduce(
            state: state,
            action: .eventReceived(EventEnvelope(eventID: "1", eventType: "run.started", createdAt: Date(), correlationID: nil, payload: [:])),
        )
        XCTAssertEqual(state.session?.status, .running)

        state = RunSessionReducer.reduce(
            state: state,
            action: .eventReceived(EventEnvelope(eventID: "2", eventType: "run.paused", createdAt: Date(), correlationID: nil, payload: [:])),
        )
        XCTAssertEqual(state.session?.status, .paused)

        state = RunSessionReducer.reduce(
            state: state,
            action: .eventReceived(EventEnvelope(eventID: "3", eventType: "run.completed", createdAt: Date(), correlationID: nil, payload: [:])),
        )
        XCTAssertEqual(state.session?.status, .completed)
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
