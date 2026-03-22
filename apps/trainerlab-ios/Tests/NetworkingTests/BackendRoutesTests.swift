import Foundation
import Networking
import XCTest

final class BackendRoutesTests: XCTestCase {
    func testAuthAPIRoutesUseExpectedPathsAndHeaders() {
        let body = Data("{}".utf8)

        let signIn = AuthAPI.signIn(body: body)
        XCTAssertEqual(signIn.path, "/api/v1/auth/token/")
        XCTAssertEqual(signIn.method, .post)
        XCTAssertEqual(signIn.body, body)
        XCTAssertFalse(signIn.requiresAuth)

        let signOut = AuthAPI.signOut(body: body)
        XCTAssertEqual(signOut.path, "/api/v1/auth/logout/")
        XCTAssertEqual(signOut.method, .post)
        XCTAssertEqual(signOut.body, body)
        XCTAssertFalse(signOut.requiresAuth)

        let refresh = AuthAPI.refresh(body: body)
        XCTAssertEqual(refresh.path, "/api/v1/auth/token/refresh/")
        XCTAssertEqual(refresh.method, .post)
        XCTAssertEqual(refresh.body, body)
        XCTAssertFalse(refresh.requiresAuth)
    }

    func testTrainerLabAPIRoutesCoverSimulationAndPresetContracts() {
        let body = Data("{\"ok\":true}".utf8)

        XCTAssertEqual(TrainerLabAPI.accessMe().path, "/api/v1/trainerlab/access/me/")
        XCTAssertEqual(
            queryPairs(TrainerLabAPI.listSessions(limit: 20, cursor: "cur", status: "running", query: "shock")),
            ["limit=20", "cursor=cur", "status=running", "q=shock"],
        )
        XCTAssertEqual(TrainerLabAPI.createSession(body: body, idempotencyKey: "id-1").idempotencyKey, "id-1")
        XCTAssertEqual(TrainerLabAPI.session(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/")
        XCTAssertEqual(TrainerLabAPI.retryInitial(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/retry-initial/")
        XCTAssertEqual(TrainerLabAPI.runtimeState(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/state/")
        XCTAssertEqual(TrainerLabAPI.controlPlaneDebug(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/control-plane/")
        XCTAssertEqual(TrainerLabAPI.runCommand(simulationID: 12, command: "start", idempotencyKey: "run-1").path, "/api/v1/trainerlab/simulations/12/run/start/")
        XCTAssertEqual(TrainerLabAPI.triggerRunTick(simulationID: 12, idempotencyKey: "tick-1").path, "/api/v1/trainerlab/simulations/12/run/tick/")
        XCTAssertEqual(TrainerLabAPI.triggerVitalsTick(simulationID: 12, idempotencyKey: "tick-2").path, "/api/v1/trainerlab/simulations/12/run/tick/vitals/")
        XCTAssertEqual(
            queryPairs(TrainerLabAPI.listEvents(simulationID: 12, cursor: "evt-2", limit: 50)),
            ["limit=50", "cursor=evt-2"],
        )
        XCTAssertEqual(TrainerLabAPI.runSummary(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/summary/")
        XCTAssertEqual(TrainerLabAPI.adjustSimulation(simulationID: 12, body: body, idempotencyKey: "adj-1").path, "/api/v1/trainerlab/simulations/12/adjust/")
        XCTAssertEqual(TrainerLabAPI.steerPrompt(simulationID: 12, body: body, idempotencyKey: "steer-1").path, "/api/v1/trainerlab/simulations/12/steer/prompt/")

        XCTAssertEqual(TrainerLabAPI.injuries(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/injuries/")
        XCTAssertEqual(TrainerLabAPI.illnesses(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/illnesses/")
        XCTAssertEqual(TrainerLabAPI.problems(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/problems/")
        XCTAssertEqual(TrainerLabAPI.assessmentFindings(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/assessment-findings/")
        XCTAssertEqual(TrainerLabAPI.diagnosticResults(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/diagnostic-results/")
        XCTAssertEqual(TrainerLabAPI.resources(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/resources/")
        XCTAssertEqual(TrainerLabAPI.disposition(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/disposition/")
        XCTAssertEqual(TrainerLabAPI.vitals(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/vitals/")
        XCTAssertEqual(TrainerLabAPI.interventions(simulationID: 12, body: body).path, "/api/v1/trainerlab/simulations/12/events/interventions/")

        XCTAssertEqual(queryPairs(TrainerLabAPI.listPresets(limit: 30, cursor: "preset-1")), ["limit=30", "cursor=preset-1"])
        XCTAssertEqual(TrainerLabAPI.presets(body: body, method: .post).path, "/api/v1/trainerlab/presets/")
        XCTAssertEqual(TrainerLabAPI.preset(presetID: 9, body: body, method: .patch).path, "/api/v1/trainerlab/presets/9/")
        XCTAssertEqual(TrainerLabAPI.duplicatePreset(presetID: 9).path, "/api/v1/trainerlab/presets/9/duplicate/")
        XCTAssertEqual(TrainerLabAPI.sharePreset(presetID: 9, body: body).path, "/api/v1/trainerlab/presets/9/share/")
        XCTAssertEqual(TrainerLabAPI.unsharePreset(presetID: 9, body: body).path, "/api/v1/trainerlab/presets/9/unshare/")
        XCTAssertEqual(TrainerLabAPI.applyPreset(presetID: 9, body: body, idempotencyKey: "apply-1").path, "/api/v1/trainerlab/presets/9/apply/")

        XCTAssertEqual(TrainerLabAPI.injuryDictionary().path, "/api/v1/trainerlab/dictionaries/injuries/")
        XCTAssertEqual(TrainerLabAPI.interventionDictionary().path, "/api/v1/trainerlab/dictionaries/interventions/")
        XCTAssertEqual(queryPairs(TrainerLabAPI.listAccounts(query: "alex", cursor: "acct-2", limit: 15)), ["q=alex", "limit=15", "cursor=acct-2"])
        XCTAssertEqual(TrainerLabAPI.problemStatus(simulationID: 12, problemID: 44, body: body, idempotencyKey: "prob-1").path, "/api/v1/trainerlab/simulations/12/problems/44/")
        XCTAssertEqual(TrainerLabAPI.notes(simulationID: 12, body: body, idempotencyKey: "note-1").path, "/api/v1/trainerlab/simulations/12/events/notes/")
        XCTAssertEqual(TrainerLabAPI.annotations(simulationID: 12).path, "/api/v1/trainerlab/simulations/12/annotations/")
        XCTAssertEqual(TrainerLabAPI.createAnnotation(simulationID: 12, body: body, idempotencyKey: "ann-1").path, "/api/v1/trainerlab/simulations/12/annotations/")
        XCTAssertEqual(TrainerLabAPI.scenarioBrief(simulationID: 12, body: body, idempotencyKey: "brief-1").path, "/api/v1/trainerlab/simulations/12/scenario-brief/")
    }

    func testChatLabAPIRoutesCoverSimulationMessagingAndToolContracts() {
        let body = Data("{\"ok\":true}".utf8)

        XCTAssertEqual(
            queryPairs(ChatLabAPI.listSimulations(limit: 25, cursor: "sim-2", status: "in_progress", query: "lee", searchMessages: true)),
            ["limit=25", "cursor=sim-2", "status=in_progress", "q=lee", "search_messages=true"],
        )
        XCTAssertEqual(ChatLabAPI.quickCreateSimulation(body: body).path, "/api/v1/simulations/quick-create/")
        XCTAssertEqual(ChatLabAPI.simulation(simulationID: 7).path, "/api/v1/simulations/7/")
        XCTAssertEqual(ChatLabAPI.endSimulation(simulationID: 7).path, "/api/v1/simulations/7/end/")
        XCTAssertEqual(ChatLabAPI.retryInitial(simulationID: 7).path, "/api/v1/simulations/7/retry-initial/")
        XCTAssertEqual(ChatLabAPI.retryFeedback(simulationID: 7).path, "/api/v1/simulations/7/retry-feedback/")
        XCTAssertEqual(ChatLabAPI.conversations(simulationID: 7).path, "/api/v1/simulations/7/conversations/")
        XCTAssertEqual(ChatLabAPI.createConversation(simulationID: 7, body: body).path, "/api/v1/simulations/7/conversations/")
        XCTAssertEqual(ChatLabAPI.conversation(simulationID: 7, conversationUUID: "uuid-1").path, "/api/v1/simulations/7/conversations/uuid-1/")
        XCTAssertEqual(
            queryPairs(ChatLabAPI.listMessages(simulationID: 7, conversationID: 9, cursor: "msg-2", order: "desc", limit: 40)),
            ["order=desc", "limit=40", "conversation_id=9", "cursor=msg-2"],
        )
        XCTAssertEqual(ChatLabAPI.createMessage(simulationID: 7, body: body).path, "/api/v1/simulations/7/messages/")
        XCTAssertEqual(ChatLabAPI.retryMessage(simulationID: 7, messageID: 55).path, "/api/v1/simulations/7/messages/55/retry/")
        XCTAssertEqual(ChatLabAPI.message(simulationID: 7, messageID: 55).path, "/api/v1/simulations/7/messages/55/")
        XCTAssertEqual(ChatLabAPI.markMessageRead(simulationID: 7, messageID: 55).path, "/api/v1/simulations/7/messages/55/read/")
        XCTAssertEqual(queryPairs(ChatLabAPI.listEvents(simulationID: 7, cursor: "evt-4", limit: 30)), ["limit=30", "cursor=evt-4"])
        XCTAssertEqual(queryPairs(ChatLabAPI.listTools(simulationID: 7, names: ["patient_history", "patient_results"])), ["names=patient_history", "names=patient_results"])
        XCTAssertEqual(ChatLabAPI.tool(simulationID: 7, toolName: "patient_results").path, "/api/v1/simulations/7/tools/patient_results/")
        XCTAssertEqual(ChatLabAPI.signOrders(simulationID: 7, body: body).path, "/api/v1/simulations/7/tools/patient_results/orders/")
        XCTAssertEqual(ChatLabAPI.submitLabOrders(simulationID: 7, body: body).path, "/api/v1/simulations/7/lab-orders/")
        XCTAssertEqual(queryPairs(ChatLabAPI.listModifierGroups(groups: ["ClinicalScenario", "Difficulty"])), ["groups=ClinicalScenario", "groups=Difficulty"])
    }

    func testEventStreamRoutesBuildExpectedSSERequests() throws {
        let trainerBaseURL = try XCTUnwrap(URL(string: "https://example.com"))
        let trainerRequest = try TrainerLabAPI
            .eventStream(simulationID: 12, cursor: "evt-9")
            .makeURLRequest(
                baseURL: trainerBaseURL,
                accessToken: "trainer-token",
            )

        XCTAssertEqual(trainerRequest.url?.absoluteString, "https://example.com/api/v1/trainerlab/simulations/12/events/stream/?cursor=evt-9")
        XCTAssertEqual(trainerRequest.httpMethod, "GET")
        XCTAssertEqual(trainerRequest.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(trainerRequest.value(forHTTPHeaderField: "Authorization"), "Bearer trainer-token")
        XCTAssertNotNil(trainerRequest.value(forHTTPHeaderField: "X-Correlation-ID"))

        let chatBaseURL = try XCTUnwrap(URL(string: "https://example.com"))
        let chatRequest = try ChatLabAPI
            .eventStream(simulationID: 7, cursor: "evt-4")
            .makeURLRequest(
                baseURL: chatBaseURL,
                accessToken: "chat-token",
            )

        XCTAssertEqual(chatRequest.url?.absoluteString, "https://example.com/api/v1/simulations/7/events/stream/?cursor=evt-4")
        XCTAssertEqual(chatRequest.httpMethod, "GET")
        XCTAssertEqual(chatRequest.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(chatRequest.value(forHTTPHeaderField: "Authorization"), "Bearer chat-token")
        XCTAssertNotNil(chatRequest.value(forHTTPHeaderField: "X-Correlation-ID"))
    }

    private func queryPairs(_ endpoint: Endpoint) -> [String] {
        endpoint.query.map { "\($0.name)=\($0.value ?? "")" }
    }
}
