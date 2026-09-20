import Foundation
import Realtime
import SharedModels
import XCTest

private final class FailingSSETransport: SSETransportProtocol {
    func stream(simulationID _: Int, cursor _: String?) -> AsyncThrowingStream<SSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: URLError(.networkConnectionLost))
        }
    }
}

private final class PollingWithEventTransport: PollingTransportProtocol {
    func fetch(simulationID _: Int, cursor _: String?) async throws -> PaginatedResponse<EventEnvelope> {
        let event = EventEnvelope(
            eventID: "event-1",
            eventType: "trainerlab.adjustment.accepted",
            createdAt: Date(),
            correlationID: nil,
            payload: ["target": .string("avpu")],
        )
        return PaginatedResponse(items: [event], nextCursor: "event-1", hasMore: false)
    }
}

private final class ExpiredCursorSSETransport: SSETransportProtocol {
    func stream(simulationID _: Int, cursor _: String?) -> AsyncThrowingStream<SSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: SSETransportError.expiredCursor)
        }
    }
}

private actor CursorRecordingPollingTransport: PollingTransportProtocol {
    private(set) var cursors: [String?] = []

    func fetch(simulationID: Int, cursor: String?) async throws -> PaginatedResponse<EventEnvelope> {
        cursors.append(cursor)
        return try await PollingWithEventTransport().fetch(simulationID: simulationID, cursor: cursor)
    }
}

final class RealtimeClientTests: XCTestCase {
    func testExpiredCursorRestartsCatchUpWithoutThePrunedCursor() async {
        let polling = CursorRecordingPollingTransport()
        let realtime = RealtimeClient(sseTransport: ExpiredCursorSSETransport(), pollingTransport: polling)
        let received = expectation(description: "retained event received")
        let eventTask = Task {
            for await event in realtime.events where event.eventID == "event-1" {
                received.fulfill()
                break
            }
        }
        await realtime.connect(simulationID: 1, cursor: "pruned-event")
        await fulfillment(of: [received], timeout: 3)
        realtime.disconnect()
        eventTask.cancel()
        let cursors = await polling.cursors
        XCTAssertFalse(cursors.isEmpty)
        XCTAssertNil(cursors.first ?? nil)
    }

    func testFallsBackToPollingAfterSSEFailure() async {
        let realtime = RealtimeClient(
            sseTransport: FailingSSETransport(),
            pollingTransport: PollingWithEventTransport(),
        )

        let eventExpectation = expectation(description: "polling event received")
        let stateExpectation = expectation(description: "polling state emitted")

        let eventTask = Task {
            for await event in realtime.events where event.eventID == "event-1" {
                eventExpectation.fulfill()
                break
            }
        }

        let stateTask = Task {
            for await state in realtime.transportStates {
                XCTAssertNotEqual(state, .connectedSSE, "A failed handshake must not report a healthy stream")
                if state == .polling {
                    stateExpectation.fulfill()
                    break
                }
            }
        }

        await realtime.connect(simulationID: 1, cursor: nil)

        await fulfillment(of: [eventExpectation, stateExpectation], timeout: 3.0)

        realtime.disconnect()
        eventTask.cancel()
        stateTask.cancel()
    }
}
