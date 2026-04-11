@testable import ChatLabiOS
import Foundation
import Networking
import SharedModels
import XCTest

private final class PatientResultsService: ChatLabServiceProtocol, @unchecked Sendable {
    var toolItems: [ChatToolState] = []

    func listSimulations(
        limit _: Int,
        cursor _: String?,
        status _: String?,
        query _: String?,
        searchMessages _: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        fatalError("unused")
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation {
        fatalError("unused")
    }

    func getSimulation(simulationID _: Int) async throws -> ChatSimulation {
        fatalError("unused")
    }

    func endSimulation(simulationID _: Int) async throws -> ChatSimulation {
        fatalError("unused")
    }

    func retryInitial(simulationID _: Int) async throws -> ChatSimulation {
        fatalError("unused")
    }

    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation {
        fatalError("unused")
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        fatalError("unused")
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        fatalError("unused")
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        fatalError("unused")
    }

    func listMessages(
        simulationID _: Int,
        conversationID _: Int?,
        cursor _: String?,
        order _: String,
        limit _: Int,
    ) async throws -> PaginatedResponse<ChatMessage> {
        fatalError("unused")
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        fatalError("unused")
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("unused")
    }

    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("unused")
    }

    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("unused")
    }

    func listEvents(simulationID _: Int, lastEventID _: String?, limit _: Int) async throws -> ChatEventReplayResponse {
        fatalError("unused")
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        ChatToolListResponse(items: toolItems)
    }

    func getTool(simulationID _: Int, toolName _: String) async throws -> ChatToolState {
        fatalError("unused")
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        fatalError("unused")
    }

    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        fatalError("unused")
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        fatalError("unused")
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        fatalError("unused")
    }

    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] {
        fatalError("unused")
    }
}

final class ChatPatientResultsTests: XCTestCase {
    func testToolStateDecodesFlatPatientResultsWithoutCreatingPanelContainer() throws {
        let json = """
        {
          "name": "patient_results",
          "display_name": "Patient Results",
          "data": [
            {
              "id": 101,
              "result_name": "WBC",
              "panel_name": "CBC",
              "value": 4.7,
              "unit": "K/uL",
              "reference_range_low": 4.0,
              "reference_range_high": 10.5,
              "flag": "normal",
              "attribute": "hematology",
              "type": "lab"
            },
            {
              "id": 102,
              "result_name": "Hemoglobin",
              "panel_name": "CBC",
              "value": 13.2,
              "unit": "g/dL",
              "reference_range_low": 12.0,
              "reference_range_high": 16.0,
              "flag": "normal",
              "attribute": "hematology",
              "type": "lab"
            }
          ],
          "is_generic": false,
          "checksum": "cbc-1"
        }
        """

        let tool = try JSONDecoder().decode(ChatToolState.self, from: Data(json.utf8))
        let results = tool.patientResults

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.displayName), ["WBC", "Hemoglobin"])
        XCTAssertEqual(results.map(\.panelName), ["CBC", "CBC"])
        XCTAssertEqual(results[0].value, .number(4.7))
        XCTAssertEqual(results[1].value, .number(13.2))
        XCTAssertFalse(results.contains(where: hasNestedValue))
    }

    func testPresentationGroupsRowsByPanelNameForDisplayOnly() {
        let results = [
            makeResult(id: 101, resultName: "WBC", panelName: "CBC", value: .number(4.7)),
            makeResult(id: 102, resultName: "Hemoglobin", panelName: "CBC", value: .number(13.2)),
        ]

        let sections = ChatPatientResultsPresentation.sections(from: results)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.panelName, "CBC")
        XCTAssertEqual(sections.first?.rows.map(\.displayName), ["WBC", "Hemoglobin"])
    }

    func testGroupingDoesNotRewriteScalarValueIntoNestedDictionary() {
        let results = [
            makeResult(id: 101, resultName: "WBC", panelName: "CBC", value: .number(4.7)),
            makeResult(id: 102, resultName: "Hemoglobin", panelName: "CBC", value: .number(13.2)),
        ]

        let sections = ChatPatientResultsPresentation.sections(from: results)

        XCTAssertEqual(sections.first?.rows.first?.value, .number(4.7))
        XCTAssertEqual(sections.first?.rows.last?.value, .number(13.2))
        XCTAssertFalse(sections.flatMap(\.rows).contains(where: hasNestedValue))
    }

    func testMixedPanelAndStandaloneResultsKeepStandaloneRowsIndependent() {
        let results = [
            makeResult(id: 201, resultName: "Troponin", panelName: nil, value: .number(0.02)),
            makeResult(id: 101, resultName: "WBC", panelName: "CBC", value: .number(4.7)),
            makeResult(id: 102, resultName: "Hemoglobin", panelName: "CBC", value: .number(13.2)),
            makeResult(id: 202, resultName: "Lactate", panelName: nil, value: .number(1.6)),
        ]

        let sections = ChatPatientResultsPresentation.sections(from: results)

        XCTAssertEqual(sections.map(\.panelName), [nil, "CBC", nil])
        XCTAssertEqual(sections[0].rows.map(\.displayName), ["Troponin"])
        XCTAssertEqual(sections[1].rows.map(\.displayName), ["WBC", "Hemoglobin"])
        XCTAssertEqual(sections[2].rows.map(\.displayName), ["Lactate"])
    }

    @MainActor
    func testToolsStoreKeepsBootstrapAndRefreshResultsInSameFlatShape() async {
        let service = PatientResultsService()
        let store = ChatToolsStore(service: service, simulationID: 42)

        let bootstrapResults = [
            makeResult(id: 101, resultName: "WBC", panelName: "CBC", value: .number(4.7)),
            makeResult(id: 102, resultName: "Hemoglobin", panelName: "CBC", value: .number(13.2)),
        ]
        service.toolItems = [makeTool(results: bootstrapResults, checksum: "bootstrap")]

        await store.loadTools()

        XCTAssertEqual(store.patientResults.map(\.rawRow), bootstrapResults.map(\.rawRow))
        XCTAssertFalse(store.patientResults.contains(where: hasNestedValue))

        let refreshedResults = [
            makeResult(id: 301, resultName: "Sodium", panelName: "CMP", value: .number(140)),
            makeResult(id: 302, resultName: "Potassium", panelName: "CMP", value: .number(4.1)),
            makeResult(id: 401, resultName: "Troponin", panelName: nil, value: .number(0.02)),
        ]
        service.toolItems = [makeTool(results: refreshedResults, checksum: "refresh")]

        await store.refreshTools()

        XCTAssertEqual(store.patientResults.map(\.rawRow), refreshedResults.map(\.rawRow))
        XCTAssertFalse(store.patientResults.contains(where: hasNestedValue))
    }

    private func makeResult(
        id: Int,
        resultName: String,
        panelName: String?,
        value: JSONValue,
        unit: String? = nil,
        referenceRangeLow: JSONValue? = nil,
        referenceRangeHigh: JSONValue? = nil,
        flag: String? = nil,
        attribute: String? = nil,
        type: String? = "lab",
    ) -> ChatPatientResult {
        var row: [String: JSONValue] = [
            "id": .number(Double(id)),
            "result_name": .string(resultName),
            "value": value,
        ]
        if let panelName {
            row["panel_name"] = .string(panelName)
        }
        if let unit {
            row["unit"] = .string(unit)
        }
        if let referenceRangeLow {
            row["reference_range_low"] = referenceRangeLow
        }
        if let referenceRangeHigh {
            row["reference_range_high"] = referenceRangeHigh
        }
        if let flag {
            row["flag"] = .string(flag)
        }
        if let attribute {
            row["attribute"] = .string(attribute)
        }
        if let type {
            row["type"] = .string(type)
        }
        return ChatPatientResult(rawRow: row)
    }

    private func makeTool(results: [ChatPatientResult], checksum: String) -> ChatToolState {
        ChatToolState(
            name: "patient_results",
            displayName: "Patient Results",
            data: results.map(\.rawRow),
            isGeneric: false,
            checksum: checksum,
        )
    }

    private func hasNestedValue(_ result: ChatPatientResult) -> Bool {
        switch result.value {
        case .object, .array:
            return true
        case .string, .number, .bool, .null, nil:
            return false
        }
    }
}
