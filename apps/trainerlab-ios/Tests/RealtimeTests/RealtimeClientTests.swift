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
            payload: ["target": .string("avpu")]
        )
        return PaginatedResponse(items: [event], nextCursor: "event-1", hasMore: false)
    }
}

final class RealtimeClientTests: XCTestCase {
    func testFallsBackToPollingAfterSSEFailure() async {
        let realtime = RealtimeClient(
            sseTransport: FailingSSETransport(),
            pollingTransport: PollingWithEventTransport()
        )

        let eventExpectation = expectation(description: "polling event received")
        let stateExpectation = expectation(description: "polling state emitted")

        let eventTask = Task {
            for await event in realtime.events {
                if event.eventID == "event-1" {
                    eventExpectation.fulfill()
                    break
                }
            }
        }

        let stateTask = Task {
            for await state in realtime.transportStates {
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
