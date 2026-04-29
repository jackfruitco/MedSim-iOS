@testable import ChatLabiOS
import Foundation
import Networking
import SharedModels
import XCTest

private enum ChatRecordingError: Error {
    case intercepted
}

private final class ChatRecordingAPIClient: APIClientProtocol, @unchecked Sendable {
    private(set) var capturedEndpoints: [Endpoint] = []

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type) async throws -> T {
        capturedEndpoints.append(endpoint)
        throw ChatRecordingError.intercepted
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        capturedEndpoints.append(endpoint)
        throw ChatRecordingError.intercepted
    }

    func baseURL() async -> URL {
        URL(string: "https://example.com")!
    }
}

final class ChatLabContractTests: XCTestCase {
    func testChatMessageDecodesCanonicalMediaFields() throws {
        let json = """
        {
          "id": 77,
          "simulation_id": 42,
          "conversation_id": 3,
          "sender_id": 0,
          "content": "XR image attached",
          "role": "assistant",
          "timestamp": "2026-03-12T12:00:00Z",
          "is_from_ai": true,
          "media_list": [
            {
              "id": 9,
              "uuid": "media-1",
              "original_url": "https://example.com/original.png",
              "thumbnail_url": "https://example.com/thumb.png",
              "mime_type": "image/png",
              "description": "Portable chest x-ray"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(ChatMessage.self, from: Data(json.utf8))

        XCTAssertEqual(message.messageType, "text")
        XCTAssertEqual(message.displayName, "")
        XCTAssertEqual(message.deliveryStatus, .sent)
        XCTAssertEqual(message.deliveryRetryCount, 0)
        XCTAssertFalse(message.isRead)
        XCTAssertEqual(message.mediaList.count, 1)
        XCTAssertEqual(message.mediaList.first?.thumbnailURL, "https://example.com/thumb.png")
        XCTAssertEqual(message.mediaList.first?.originalURL, "https://example.com/original.png")
    }

    func testChatSimulationDecodesLatestEventID() throws {
        let json = """
        {
          "id": 42,
          "user_id": 9,
          "start_timestamp": "2026-03-12T12:00:00Z",
          "end_timestamp": null,
          "time_limit_seconds": 600,
          "diagnosis": "Trauma",
          "chief_complaint": "Chest pain",
          "patient_display_name": "Alex Morgan",
          "patient_initials": "AM",
          "status": "failed",
          "terminal_reason_code": "initial_generation_timeout",
          "terminal_reason_text": "Initial generation failed",
          "terminal_at": "2026-03-12T12:01:30Z",
          "retryable": true,
          "latest_event_id": "evt-42"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let simulation = try decoder.decode(ChatSimulation.self, from: Data(json.utf8))

        XCTAssertEqual(simulation.id, 42)
        XCTAssertEqual(simulation.status, .failed)
        XCTAssertEqual(simulation.latestEventID, "evt-42")
        XCTAssertEqual(simulation.terminalReasonCode, "initial_generation_timeout")
        XCTAssertEqual(simulation.retryable, true)
    }

    func testChatEventEnvelopeDecodesCanonicalWebSocketShape() throws {
        let json = """
        {
          "event_id": "evt-1",
          "event_type": "message.item.created",
          "created_at": "2026-03-12T12:00:00Z",
          "correlation_id": "corr-1",
          "payload": {
            "message_id": 19,
            "content": "hello"
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ChatEventEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(event.eventID, "evt-1")
        XCTAssertEqual(event.eventType, SimulationEventType.messageItemCreated)
        XCTAssertEqual(event.chatEventKind, .messageItemCreated)
        XCTAssertEqual(event.correlationID, "corr-1")
        XCTAssertEqual(event.payload["message_id"], .number(19))
    }

    func testCanonicalChatEventKindsDecodeFromBackendNames() {
        let names: [String: ChatSimulationEventKind] = [
            SimulationEventType.messageItemCreated: .messageItemCreated,
            SimulationEventType.messageDeliveryUpdated: .messageDeliveryUpdated,
            SimulationEventType.feedbackItemCreated: .feedbackItemCreated,
            SimulationEventType.feedbackGenerationFailed: .feedbackGenerationFailed,
            SimulationEventType.feedbackGenerationUpdated: .feedbackGenerationUpdated,
            SimulationEventType.patientMetadataCreated: .patientMetadataCreated,
            SimulationEventType.patientResultsUpdated: .patientResultsUpdated,
            SimulationEventType.guardStateUpdated: .guardStateUpdated,
            SimulationEventType.guardWarningUpdated: .guardWarningUpdated,
        ]

        for (rawValue, expectedType) in names {
            let envelope = ChatEventEnvelope(
                eventID: "evt-\(rawValue)",
                eventType: rawValue,
                createdAt: Date(),
                correlationID: "corr-1",
                payload: [:],
            )
            XCTAssertEqual(envelope.chatEventKind, expectedType, "Expected \(rawValue) to decode to \(expectedType)")
        }
    }

    func testUnknownChatEventKindFallsBackSafely() {
        let envelope = ChatEventEnvelope(
            eventID: "evt-unknown",
            eventType: "message.item.renamed",
            createdAt: Date(),
            correlationID: "corr-unknown",
            payload: [:],
        )

        XCTAssertEqual(
            envelope.chatEventKind,
            .unknown(rawValue: "message.item.renamed"),
        )
    }

    func testReplayResponseDecodesNextEventID() throws {
        let json = """
        {
          "items": [],
          "next_event_id": "evt-447",
          "has_more": true
        }
        """

        let response = try JSONDecoder().decode(ChatEventReplayResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.nextEventID, "evt-447")
        XCTAssertTrue(response.hasMore)
    }

    func testModifierGroupDecodesBackendCatalogShape() throws {
        let json = """
        [
          {
            "key": "clinical_scenario",
            "label": "Clinical Scenario",
            "description": "Type of clinical encounter",
            "selection": {
              "mode": "single",
              "required": false
            },
            "modifiers": [
              {
                "key": "musculoskeletal",
                "label": "Musculoskeletal",
                "description": "Musculoskeletal injury or issue scenario"
              }
            ]
          }
        ]
        """

        let groups = try JSONDecoder().decode([ModifierGroup].self, from: Data(json.utf8))

        XCTAssertEqual(groups.first?.key, "clinical_scenario")
        XCTAssertEqual(groups.first?.label, "Clinical Scenario")
        XCTAssertEqual(groups.first?.selection.mode, .single)
        XCTAssertEqual(groups.first?.selection.required, false)
        XCTAssertEqual(groups.first?.modifiers.first?.key, "musculoskeletal")
        XCTAssertEqual(groups.first?.modifiers.first?.label, "Musculoskeletal")
    }

    func testRealtimeHelpersUseWebSocketOnlyRoutesAndLastEventIDQuery() async throws {
        let api = ChatRecordingAPIClient()
        let service = ChatLabService(apiClient: api)

        XCTAssertEqual(ChatLabAPI.realtimeSocket().path, "/ws/v1/chatlab/")

        do {
            _ = try await service.listEvents(
                simulationID: 7,
                lastEventID: "evt-22",
                limit: 10,
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }

        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/events/")
        XCTAssertEqual(
            api.capturedEndpoints.last?.query.first(where: { $0.name == "last_event_id" })?.value,
            "evt-22",
        )
    }

    func testListModifierGroupsUsesLabTypeQuery() async throws {
        let api = ChatRecordingAPIClient()
        let service = ChatLabService(apiClient: api)

        do {
            _ = try await service.listModifierGroups(labType: "chatlab")
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }

        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/config/modifier-groups/")
        XCTAssertEqual(api.capturedEndpoints.last?.query, [URLQueryItem(name: "lab_type", value: "chatlab")])
    }
}
