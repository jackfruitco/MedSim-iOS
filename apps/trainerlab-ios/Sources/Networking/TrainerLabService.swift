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
    func retryInitialSimulation(simulationID: Int) async throws -> TrainerSessionDTO
    func getRuntimeState(simulationID: Int) async throws -> TrainerRestViewModelDTO
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

    func getGuardState(simulationID: Int) async throws -> GuardStateDTO
    func sendHeartbeat(simulationID: Int) async throws -> GuardStateDTO

    func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws
}

public final class TrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let encoder = JSONEncoder()

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func accessMe() async throws -> LabAccess {
        try await apiClient.request(TrainerLabAPI.accessMe(), as: LabAccess.self)
    }

    public func listSessions(limit: Int = 20, cursor: String? = nil, status: String? = nil, query searchQuery: String? = nil) async throws -> PaginatedResponse<TrainerSessionDTO> {
        try await apiClient.request(
            TrainerLabAPI.listSessions(limit: limit, cursor: cursor, status: status, query: searchQuery),
            as: PaginatedResponse<TrainerSessionDTO>.self,
        )
    }

    public func createSession(request: TrainerSessionCreateRequest, idempotencyKey: String) async throws -> TrainerSessionDTO {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.createSession(body: body, idempotencyKey: idempotencyKey),
            as: TrainerSessionDTO.self,
        )
    }

    public func getSession(simulationID: Int) async throws -> TrainerSessionDTO {
        try await apiClient.request(
            TrainerLabAPI.session(simulationID: simulationID),
            as: TrainerSessionDTO.self,
        )
    }

    public func retryInitialSimulation(simulationID: Int) async throws -> TrainerSessionDTO {
        _ = try await apiClient.requestData(TrainerLabAPI.retryInitial(simulationID: simulationID))
        return try await getSession(simulationID: simulationID)
    }

    public func getRuntimeState(simulationID: Int) async throws -> TrainerRestViewModelDTO {
        try await apiClient.request(
            TrainerLabAPI.runtimeState(simulationID: simulationID),
            as: TrainerRestViewModelDTO.self,
        )
    }

    public func getControlPlaneDebug(simulationID: Int) async throws -> ControlPlaneDebugOut {
        try await apiClient.request(
            TrainerLabAPI.controlPlaneDebug(simulationID: simulationID),
            as: ControlPlaneDebugOut.self,
        )
    }

    public func runCommand(
        simulationID: Int,
        command: RunCommand,
        idempotencyKey: String,
    ) async throws -> TrainerSessionDTO {
        try await apiClient.request(
            TrainerLabAPI.runCommand(
                simulationID: simulationID,
                command: command.rawValue,
                idempotencyKey: idempotencyKey,
            ),
            as: TrainerSessionDTO.self,
        )
    }

    public func triggerRunTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck {
        try await apiClient.request(
            TrainerLabAPI.triggerRunTick(simulationID: simulationID, idempotencyKey: idempotencyKey),
            as: TrainerCommandAck.self,
        )
    }

    public func triggerVitalsTick(simulationID: Int, idempotencyKey: String) async throws -> TrainerCommandAck {
        try await apiClient.request(
            TrainerLabAPI.triggerVitalsTick(simulationID: simulationID, idempotencyKey: idempotencyKey),
            as: TrainerCommandAck.self,
        )
    }

    public func listEvents(
        simulationID: Int,
        cursor: String?,
        limit: Int,
    ) async throws -> PaginatedResponse<EventEnvelope> {
        try await apiClient.request(
            TrainerLabAPI.listEvents(simulationID: simulationID, cursor: cursor, limit: limit),
            as: PaginatedResponse<EventEnvelope>.self,
        )
    }

    public func getRunSummary(simulationID: Int) async throws -> RunSummary {
        try await apiClient.request(
            TrainerLabAPI.runSummary(simulationID: simulationID),
            as: RunSummary.self,
        )
    }

    public func adjustSimulation(simulationID: Int, request: SimulationAdjustRequest, idempotencyKey: String) async throws -> SimulationAdjustAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.adjustSimulation(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
            as: SimulationAdjustAck.self,
        )
    }

    public func steerPrompt(
        simulationID: Int,
        request: SteerPromptRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.steerPrompt(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
            as: TrainerCommandAck.self,
        )
    }

    public func injectInjuryEvent(
        simulationID: Int,
        request: InjuryEventRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.injuries(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func injectIllnessEvent(
        simulationID: Int,
        request: IllnessEventRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.illnesses(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func createProblem(
        simulationID: Int,
        request: ProblemCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.problems(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func createAssessmentFinding(
        simulationID: Int,
        request: AssessmentFindingCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.assessmentFindings(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
        )
    }

    public func createDiagnosticResult(
        simulationID: Int,
        request: DiagnosticResultCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.diagnosticResults(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
        )
    }

    public func createResourceState(
        simulationID: Int,
        request: ResourceStateCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.resources(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func createDispositionState(
        simulationID: Int,
        request: DispositionStateCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.disposition(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func injectVitalEvent(
        simulationID: Int,
        request: VitalEventRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.vitals(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
        )
    }

    public func injectInterventionEvent(
        simulationID: Int,
        request: InterventionEventRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await injectEvent(
            TrainerLabAPI.interventions(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
        )
    }

    private func injectEvent(_ endpoint: Endpoint) async throws -> TrainerCommandAck {
        try await apiClient.request(
            endpoint,
            as: TrainerCommandAck.self,
        )
    }

    public func listPresets(limit: Int, cursor: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        try await apiClient.request(
            TrainerLabAPI.listPresets(limit: limit, cursor: cursor),
            as: PaginatedResponse<ScenarioInstruction>.self,
        )
    }

    public func createPreset(request: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.presets(body: body, method: .post),
            as: ScenarioInstruction.self,
        )
    }

    public func getPreset(presetID: Int) async throws -> ScenarioInstruction {
        try await apiClient.request(
            TrainerLabAPI.preset(presetID: presetID),
            as: ScenarioInstruction.self,
        )
    }

    public func updatePreset(presetID: Int, request: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.preset(presetID: presetID, body: body, method: .patch),
            as: ScenarioInstruction.self,
        )
    }

    public func deletePreset(presetID: Int) async throws {
        _ = try await apiClient.requestData(TrainerLabAPI.preset(presetID: presetID, method: .delete))
    }

    public func duplicatePreset(presetID: Int) async throws -> ScenarioInstruction {
        try await apiClient.request(
            TrainerLabAPI.duplicatePreset(presetID: presetID),
            as: ScenarioInstruction.self,
        )
    }

    public func sharePreset(presetID: Int, request: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.sharePreset(presetID: presetID, body: body),
            as: ScenarioInstructionPermission.self,
        )
    }

    public func unsharePreset(presetID: Int, request: ScenarioInstructionUnshareRequest) async throws {
        let body = try encoder.encode(request)
        _ = try await apiClient.requestData(TrainerLabAPI.unsharePreset(presetID: presetID, body: body))
    }

    public func applyPreset(presetID: Int, request: ScenarioInstructionApplyRequest, idempotencyKey: String) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.applyPreset(presetID: presetID, body: body, idempotencyKey: idempotencyKey),
            as: TrainerCommandAck.self,
        )
    }

    public func injuryDictionary() async throws -> InjuryDictionary {
        try await apiClient.request(TrainerLabAPI.injuryDictionary(), as: InjuryDictionary.self)
    }

    public func interventionDictionary() async throws -> [InterventionGroup] {
        try await apiClient.request(TrainerLabAPI.interventionDictionary(), as: [InterventionGroup].self)
    }

    public func listAccounts(query: String, cursor: String?, limit: Int) async throws -> PaginatedResponse<AccountListUser> {
        try await apiClient.request(
            TrainerLabAPI.listAccounts(query: query, cursor: cursor, limit: limit),
            as: PaginatedResponse<AccountListUser>.self,
        )
    }

    public func updateProblemStatus(
        simulationID: Int,
        problemID: Int,
        request: ProblemStatusUpdateRequest,
        idempotencyKey: String,
    ) async throws -> ProblemStatusOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.problemStatus(
                simulationID: simulationID,
                problemID: problemID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
            as: ProblemStatusOut.self,
        )
    }

    public func createNoteEvent(
        simulationID: Int,
        request: SimulationNoteCreateRequest,
        idempotencyKey: String,
    ) async throws -> TrainerCommandAck {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.notes(simulationID: simulationID, body: body, idempotencyKey: idempotencyKey),
            as: TrainerCommandAck.self,
        )
    }

    public func createAnnotation(
        simulationID: Int,
        request: AnnotationCreateRequest,
        idempotencyKey: String,
    ) async throws -> AnnotationOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.createAnnotation(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
            as: AnnotationOut.self,
        )
    }

    public func listAnnotations(simulationID: Int) async throws -> [AnnotationOut] {
        try await apiClient.request(
            TrainerLabAPI.annotations(simulationID: simulationID),
            as: [AnnotationOut].self,
        )
    }

    public func updateScenarioBrief(
        simulationID: Int,
        request: ScenarioBriefUpdateRequest,
        idempotencyKey: String,
    ) async throws -> ScenarioBriefOut {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            TrainerLabAPI.scenarioBrief(
                simulationID: simulationID,
                body: body,
                idempotencyKey: idempotencyKey,
            ),
            as: ScenarioBriefOut.self,
        )
    }

    public func getGuardState(simulationID: Int) async throws -> GuardStateDTO {
        try await apiClient.request(TrainerLabAPI.guardState(simulationID: simulationID), as: GuardStateDTO.self)
    }

    public func sendHeartbeat(simulationID: Int) async throws -> GuardStateDTO {
        try await apiClient.request(TrainerLabAPI.heartbeat(simulationID: simulationID), as: GuardStateDTO.self)
    }

    public func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws {
        let requestMethod = HTTPMethod(rawValue: method.uppercased()) ?? .post
        _ = try await apiClient.requestData(
            Endpoint(path: endpoint, method: requestMethod, body: body, idempotencyKey: idempotencyKey),
        )
    }
}
