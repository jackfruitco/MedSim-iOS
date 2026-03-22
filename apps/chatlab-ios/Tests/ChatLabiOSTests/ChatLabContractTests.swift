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
    func testChatMessageDecodesBackendDefaultsAndMediaList() throws {
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
              "thumbnail_url": "https://example.com/thumb.png"
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
        XCTAssertEqual(message.mediaList.first?.url, "https://example.com/thumb.png")
    }

    func testChatSSEParserDecodesBackendEventEnvelope() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = """
        {
          "event_id": "evt-1",
          "event_type": "message.item.created",
          "created_at": "2026-03-12T12:00:00Z",
          "correlation_id": null,
          "payload": {
            "message_id": 19,
            "content": "hello"
          }
        }
        """

        let event = try ChatSSEParser.parseEvent(dataString: data, decoder: decoder)
        XCTAssertEqual(event?.eventID, "evt-1")
        XCTAssertEqual(event?.eventType, SimulationEventType.messageItemCreated)
    }

    func testLegacyChatAliasCanonicalizesForIngressHandling() {
        let legacy = ChatEventEnvelope(
            eventID: "evt-legacy",
            eventType: "chat.message_created",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        )

        XCTAssertEqual(legacy.canonicalized().eventType, SimulationEventType.messageItemCreated)
    }

    func testChatSimulationDecodesTerminalFields() throws {
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
          "retryable": true
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let simulation = try decoder.decode(ChatSimulation.self, from: Data(json.utf8))

        XCTAssertEqual(simulation.id, 42)
        XCTAssertEqual(simulation.status, .failed)
        XCTAssertEqual(simulation.terminalReasonCode, "initial_generation_timeout")
        XCTAssertEqual(simulation.retryable, true)
    }

    func testChatLabServiceUsesExpectedEndpoints() async throws {
        let api = ChatRecordingAPIClient()
        let service = ChatLabService(apiClient: api)

        do {
            _ = try await service.quickCreateSimulation(request: ChatQuickCreateRequest(modifiers: ["a", "b"]))
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/quick-create/")

        do {
            _ = try await service.listMessages(
                simulationID: 7,
                conversationID: 3,
                cursor: "22",
                order: "desc",
                limit: 10,
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/messages/")
        XCTAssertEqual(api.capturedEndpoints.last?.query.count, 4)

        do {
            _ = try await service.listTools(simulationID: 7, names: ["patient_history"])
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/tools/")

        do {
            _ = try await service.signOrders(
                simulationID: 7,
                request: ChatSignOrdersRequest(submittedOrders: ["CBC"]),
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/tools/patient_results/orders/")

        do {
            _ = try await service.markMessageRead(simulationID: 7, messageID: 55)
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/messages/55/read/")
        XCTAssertEqual(api.capturedEndpoints.last?.method, .patch)

        do {
            _ = try await service.submitLabOrders(
                simulationID: 7,
                request: ChatSubmitLabOrdersRequest(orders: ["CBC"]),
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/lab-orders/")
        XCTAssertEqual(api.capturedEndpoints.last?.method, .post)
        XCTAssertEqual(
            try decodeJSONBody(api.capturedEndpoints.last?.body)?["orders"] as? [String],
            ["CBC"],
        )

        do {
            _ = try await service.listModifierGroups(groups: ["ClinicalScenario"])
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/config/modifier-groups/")
    }

    private func decodeJSONBody(_ data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
}
