import Foundation
import ChatLabiOS
import Networking
import SharedModels
import XCTest

private enum ChatRecordingError: Error {
    case intercepted
}

private final class ChatRecordingAPIClient: APIClientProtocol, @unchecked Sendable {
    private(set) var capturedEndpoints: [Endpoint] = []

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
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
                limit: 10
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
                request: ChatSignOrdersRequest(submittedOrders: ["CBC"])
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/simulations/7/tools/patient_results/orders/")

        do {
            _ = try await service.listModifierGroups(groups: ["ClinicalScenario"])
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is ChatRecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/config/modifier-groups/")
    }
}
