import Foundation
import SharedModels

public enum RunCommand: String, Sendable {
    case start
    case pause
    case resume
    case stop
}

public protocol TrainerLabServiceProtocol: Sendable {
    func accessMe() async throws -> LabAccess

    func listSessions(limit: Int, cursor: String?, status: String?, query: String?) async throws -> PaginatedResponse<TrainerSessionDTO>
    func createSession(request: TrainerSessionCreateRequest, idempotencyKey: String) async throws -> TrainerSessionDTO
    func getSession(simulationID: Int) async throws -> TrainerSessionDTO
    func getRuntimeState(simulationID: Int) async throws -> TrainerRuntimeStateOut
    func getControlPlaneDebug(simulationID: Int) async throws -> ControlPlaneDebugOut
    func runCommand(simulationID: Int, command: RunCommand, idempotencyKey: String) async throws -> TrainerSessionDTO
    func triggerRunTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck
    func triggerVitalsTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck

    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<EventEnvelope>
    func getRunSummary(simulationID: Int) async throws -> RunSummary

    func adjustSimulation(simulationID: Int, request: SimulationAdjustRequest, idempotencyKey: String) async throws -> SimulationAdjustAck
    func steerPrompt(simulationID: Int, request: SteerPromptRequest, idempotencyKey: String) async throws -> TrainerCommandAck

    func injectInjuryEvent(simulationID: Int, request: InjuryEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func injectIllnessEvent(simulationID: Int, request: IllnessEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createProblem(simulationID: Int, request: ProblemCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createAssessmentFinding(simulationID: Int, request: AssessmentFindingCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createDiagnosticResult(simulationID: Int, request: DiagnosticResultCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createResourceState(simulationID: Int, request: ResourceStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createDispositionState(simulationID: Int, request: DispositionStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func injectVitalEvent(simulationID: Int, request: VitalEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func injectInterventionEvent(simulationID: Int, request: InterventionEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck

    func listPresets(limit: Int, cursor: String?) async throws -> PaginatedResponse<ScenarioInstruction>
    func createPreset(request: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction
    func getPreset(presetID: Int) async throws -> ScenarioInstruction
    func updatePreset(presetID: Int, request: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction
    func deletePreset(presetID: Int) async throws
    func duplicatePreset(presetID: Int) async throws -> ScenarioInstruction
    func sharePreset(presetID: Int, request: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission
    func unsharePreset(presetID: Int, request: ScenarioInstructionUnshareRequest) async throws
    func applyPreset(presetID: Int, request: ScenarioInstructionApplyRequest, idempotencyKey: String) async throws -> TrainerCommandAck

    func injuryDictionary() async throws -> InjuryDictionary
    func interventionDictionary() async throws -> [InterventionGroup]

    func listAccounts(query: String, cursor: String?, limit: Int) async throws -> PaginatedResponse<AccountListUser>

    func updateProblemStatus(simulationID: Int, problemID: Int, request: ProblemStatusUpdateRequest, idempotencyKey: String) async throws -> ProblemStatusOut
    func createNoteEvent(simulationID: Int, request: SimulationNoteCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck
    func createAnnotation(simulationID: Int, request: AnnotationCreateRequest, idempotencyKey: String) async throws -> AnnotationOut
    func listAnnotations(simulationID: Int) async throws -> [AnnotationOut]
    func updateScenarioBrief(simulationID: Int, request: ScenarioBriefUpdateRequest, idempotencyKey: String) async throws -> ScenarioBriefOut

    func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws
}

public final class TrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let encoder = JSONEncoder()

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func accessMe() async throws -> LabAccess {
        try await apiClient.request(Endpoint(path: "/api/v1/trainerlab/access/me/"), as: LabAccess.self)
    }

    public func listSessions(limit: Int = 20, cursor: String? = nil, status: String? = nil, query searchQuery: String? = nil) async throws -> PaginatedResponse<TrainerSessionDTO> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let status {
            query.append(URLQueryItem(name: "status", value: status))
        }
        if let searchQuery, !searchQuery.isEmpty {
            query.append(URLQueryItem(name: "q", value: searchQuery))
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/", query: query),
            as: PaginatedResponse<TrainerSessionDTO>.self
        )
    }

    public func createSession(request: TrainerSessionCreateRequest, idempotencyKey: String) async throws -> TrainerSessionDTO {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: TrainerSessionDTO.self
        )
    }

    public func getSession(simulationID: Int) async throws -> TrainerSessionDTO {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/"),
            as: TrainerSessionDTO.self
        )
    }

    public func getRuntimeState(simulationID: Int) async throws -> TrainerRuntimeStateOut {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/state/"),
            as: TrainerRuntimeStateOut.self
        )
    }

    public func getControlPlaneDebug(simulationID: Int) async throws -> ControlPlaneDebugOut {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/control-plane/"),
            as: ControlPlaneDebugOut.self
        )
    }

    public func runCommand(
        simulationID: Int,
        command: RunCommand,
        idempotencyKey: String
    ) async throws -> TrainerSessionDTO {
        try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/run/\(command.rawValue)/",
                method: .post,
                body: Data(),
                idempotencyKey: idempotencyKey
            ),
            as: TrainerSessionDTO.self
        )
    }

    public func triggerRunTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck {
        try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/",
                method: .post,
                body: Data(),
                idempotencyKey: idempotencyKey
            ),
            as: TrainerCommandAck.self
        )
    }

    public func triggerVitalsTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck {
        try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/vitals/",
                method: .post,
                body: Data(),
                idempotencyKey: idempotencyKey
            ),
            as: TrainerCommandAck.self
        )
    }

    public func listEvents(
        simulationID: Int,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<EventEnvelope> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/events/", query: query),
            as: PaginatedResponse<EventEnvelope>.self
        )
    }

    public func getRunSummary(simulationID: Int) async throws -> RunSummary {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/summary/"),
            as: RunSummary.self
        )
    }

    public func adjustSimulation(simulationID: Int, request: SimulationAdjustRequest, idempotencyKey: String) async throws -> SimulationAdjustAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/adjust/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: SimulationAdjustAck.self
        )
    }

    public func steerPrompt(
        simulationID: Int,
        request: SteerPromptRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/steer/prompt/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: TrainerCommandAck.self
        )
    }

    public func injectInjuryEvent(
        simulationID: Int,
        request: InjuryEventRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/injuries/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func injectIllnessEvent(
        simulationID: Int,
        request: IllnessEventRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/illnesses/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func createProblem(
        simulationID: Int,
        request: ProblemCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/problems/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func createAssessmentFinding(
        simulationID: Int,
        request: AssessmentFindingCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/assessment-findings/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func createDiagnosticResult(
        simulationID: Int,
        request: DiagnosticResultCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/diagnostic-results/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func createResourceState(
        simulationID: Int,
        request: ResourceStateCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/resources/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func createDispositionState(
        simulationID: Int,
        request: DispositionStateCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/disposition/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func injectVitalEvent(
        simulationID: Int,
        request: VitalEventRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/vitals/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    public func injectInterventionEvent(
        simulationID: Int,
        request: InterventionEventRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        try await injectEvent(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/interventions/",
            request: request,
            idempotencyKey: idempotencyKey
        )
    }

    private func injectEvent<RequestBody: Encodable>(path: String, request: RequestBody, idempotencyKey: String) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: path, method: .post, body: body, idempotencyKey: idempotencyKey),
            as: TrainerCommandAck.self
        )
    }

    public func listPresets(limit: Int, cursor: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/", query: query),
            as: PaginatedResponse<ScenarioInstruction>.self
        )
    }

    public func createPreset(request: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/", method: .post, body: body),
            as: ScenarioInstruction.self
        )
    }

    public func getPreset(presetID: Int) async throws -> ScenarioInstruction {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/"),
            as: ScenarioInstruction.self
        )
    }

    public func updatePreset(presetID: Int, request: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/", method: .patch, body: body),
            as: ScenarioInstruction.self
        )
    }

    public func deletePreset(presetID: Int) async throws {
        _ = try await apiClient.requestData(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/", method: .delete)
        )
    }

    public func duplicatePreset(presetID: Int) async throws -> ScenarioInstruction {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/duplicate/", method: .post, body: Data()),
            as: ScenarioInstruction.self
        )
    }

    public func sharePreset(presetID: Int, request: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/share/", method: .post, body: body),
            as: ScenarioInstructionPermission.self
        )
    }

    public func unsharePreset(presetID: Int, request: ScenarioInstructionUnshareRequest) async throws {
        let body = try encoder.encode(request)
        _ = try await apiClient.requestData(
            Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/unshare/", method: .post, body: body)
        )
    }

    public func applyPreset(presetID: Int, request: ScenarioInstructionApplyRequest, idempotencyKey: String) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/presets/\(presetID)/apply/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: TrainerCommandAck.self
        )
    }

    public func injuryDictionary() async throws -> InjuryDictionary {
        try await apiClient.request(Endpoint(path: "/api/v1/trainerlab/dictionaries/injuries/"), as: InjuryDictionary.self)
    }

    public func interventionDictionary() async throws -> [InterventionGroup] {
        try await apiClient.request(Endpoint(path: "/api/v1/trainerlab/dictionaries/interventions/"), as: [InterventionGroup].self)
    }

    public func listAccounts(query: String, cursor: String?, limit: Int) async throws -> PaginatedResponse<AccountListUser> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/account/list/", query: queryItems),
            as: PaginatedResponse<AccountListUser>.self
        )
    }

    public func updateProblemStatus(
        simulationID: Int,
        problemID: Int,
        request: ProblemStatusUpdateRequest,
        idempotencyKey: String
    ) async throws -> ProblemStatusOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/problems/\(problemID)/",
                method: .patch,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: ProblemStatusOut.self
        )
    }

    public func createNoteEvent(
        simulationID: Int,
        request: SimulationNoteCreateRequest,
        idempotencyKey: String
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/events/notes/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: TrainerCommandAck.self
        )
    }

    public func createAnnotation(
        simulationID: Int,
        request: AnnotationCreateRequest,
        idempotencyKey: String
    ) async throws -> AnnotationOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/annotations/",
                method: .post,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: AnnotationOut.self
        )
    }

    public func listAnnotations(simulationID: Int) async throws -> [AnnotationOut] {
        try await apiClient.request(
            Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/annotations/"),
            as: [AnnotationOut].self
        )
    }

    public func updateScenarioBrief(
        simulationID: Int,
        request: ScenarioBriefUpdateRequest,
        idempotencyKey: String
    ) async throws -> ScenarioBriefOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(
                path: "/api/v1/trainerlab/simulations/\(simulationID)/scenario-brief/",
                method: .patch,
                body: body,
                idempotencyKey: idempotencyKey
            ),
            as: ScenarioBriefOut.self
        )
    }

    public func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws {
        let requestMethod = HTTPMethod(rawValue: method.uppercased()) ?? .post
        _ = try await apiClient.requestData(
            Endpoint(path: endpoint, method: requestMethod, body: body, idempotencyKey: idempotencyKey)
        )
    }
}
