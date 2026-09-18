//
//  MedSimApp.swift
//  MedSim
//
//  Created by Tyler Johnson on 2/8/26.
//

import AppShell
import Auth
import ChatLabiOS
import Networking
import Sessions
import SharedModels
import SwiftUI
import UIKit

@main
struct MedSimApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MedSimRootView()
        }
    }
}

private struct MedSimRootView: View {
    private let orientationCoordinator = OrientationCoordinator.shared

    var body: some View {
        if let demoScreen = ReadmeScreenshotScreen.current {
            ReadmeScreenshotView(screen: demoScreen)
        } else {
            AppShellRootView()
                .onPreferenceChange(AppShellOrientationPreferenceKey.self) { lock in
                    orientationCoordinator.apply(lock: lock)
                }
                .onAppear {
                    orientationCoordinator.reset()
                }
        }
    }
}

private enum ReadmeScreenshotScreen: String {
    case auth
    case trainerHub = "trainer-hub"
    case chatLab = "chat-lab"
    case chatRun = "chat-run"

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let screenIndex = arguments.firstIndex(of: "-readme-screenshot-screen"),
              arguments.indices.contains(screenIndex + 1)
        else {
            return nil
        }
        return Self(rawValue: arguments[screenIndex + 1])
    }
}

private struct ReadmeScreenshotView: View {
    let screen: ReadmeScreenshotScreen

    var body: some View {
        switch screen {
        case .auth:
            ReadmeAuthScreenshotView()
        case .trainerHub:
            NavigationStack {
                SessionHubView(
                    viewModel: SessionHubViewModel(service: ReadmeDemoTrainerService()),
                    onSelectSession: { _ in },
                    onOpenPresets: {},
                )
            }
        case .chatLab:
            NavigationStack {
                ChatLabHomeView(
                    store: ChatLabHomeStore(service: ReadmeDemoChatService()),
                    onOpenSimulation: { _ in },
                )
            }
        case .chatRun:
            ReadmeChatRunScreenshotView()
        }
    }
}

private struct ReadmeChatRunScreenshotView: View {
    @StateObject private var runStore: ChatRunStore
    @StateObject private var toolsStore: ChatToolsStore

    init() {
        let service = ReadmeDemoChatService()
        let simulation = ReadmeDemoChatService.activeSimulation
        _runStore = StateObject(
            wrappedValue: ChatRunStore(
                service: service,
                realtimeClient: ReadmeDemoRealtimeClient(),
                voiceClient: ReadmeDemoVoiceClient(),
                simulation: simulation,
                currentUserIdentity: ChatCurrentUserIdentity(id: simulation.userID),
            ),
        )
        _toolsStore = StateObject(
            wrappedValue: ChatToolsStore(service: service, simulationID: simulation.id),
        )
    }

    var body: some View {
        ChatRunView(
            store: runStore,
            toolsStore: toolsStore,
            feedbackService: ReadmeDemoFeedbackService(),
            feedbackHeaderProvider: FeedbackRequestHeaderProvider(sessionID: "readme-demo"),
            mediaLoader: ReadmeDemoMediaLoader(),
            haptics: ReadmeDemoHaptics(),
            onBack: {},
        )
    }
}

private struct ReadmeAuthScreenshotView: View {
    var body: some View {
        AuthGateView(
            viewModel: AuthViewModel(
                authService: ReadmeDemoAuthService(),
                trainerService: ReadmeDemoTrainerService(),
            ),
            appTitle: "MedSim",
            appSubtitle: "TrainerLab + ChatLab",
            environmentLabel: "Env: staging | medsim-staging.jackfruitco.com",
            onOpenEnvironmentSwitcher: {},
        )
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            _ = await MainActor.run {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

private struct ReadmeDemoAuthService: AuthServiceProtocol {
    func signIn(email _: String, password _: String) async throws -> AuthTokens {
        AuthTokens(
            accessToken: "demo-access-token",
            refreshToken: "demo-refresh-token",
            expiresIn: 3600,
            tokenType: "Bearer",
        )
    }

    func signOut() async {}

    func hasActiveTokens() -> Bool {
        false
    }
}

private struct ReadmeDemoTrainerService: TrainerLabServiceProtocol {
    private let sampleSessions = [
        TrainerSessionDTO(
            simulationID: 4821,
            status: .running,
            scenarioSpec: [
                "diagnosis": .string("Tension pneumothorax"),
                "chief_complaint": .string("Progressive respiratory distress"),
            ],
            runtimeState: [:],
            initialDirectives: "Start unstable and escalate if decompression is delayed.",
            tickIntervalSeconds: 10,
            runStartedAt: Date().addingTimeInterval(-2100),
            runPausedAt: nil,
            runCompletedAt: nil,
            lastAITickAt: Date().addingTimeInterval(-30),
            createdAt: Date().addingTimeInterval(-2400),
            modifiedAt: Date().addingTimeInterval(-20),
        ),
        TrainerSessionDTO(
            simulationID: 4819,
            status: .paused,
            scenarioSpec: [
                "diagnosis": .string("Hemorrhagic shock"),
                "chief_complaint": .string("Blast injury with active bleeding"),
            ],
            runtimeState: [:],
            initialDirectives: "Limited blood products, delayed evac.",
            tickIntervalSeconds: 15,
            runStartedAt: Date().addingTimeInterval(-5400),
            runPausedAt: Date().addingTimeInterval(-600),
            runCompletedAt: nil,
            lastAITickAt: Date().addingTimeInterval(-600),
            createdAt: Date().addingTimeInterval(-5600),
            modifiedAt: Date().addingTimeInterval(-580),
        ),
        TrainerSessionDTO(
            simulationID: 4814,
            status: .completed,
            scenarioSpec: [
                "diagnosis": .string("Hypothermia"),
                "chief_complaint": .string("Cold exposure during extraction"),
            ],
            runtimeState: [:],
            initialDirectives: "Track warming measures and disposition timing.",
            tickIntervalSeconds: 12,
            runStartedAt: Date().addingTimeInterval(-9200),
            runPausedAt: nil,
            runCompletedAt: Date().addingTimeInterval(-7200),
            lastAITickAt: Date().addingTimeInterval(-7200),
            createdAt: Date().addingTimeInterval(-9400),
            modifiedAt: Date().addingTimeInterval(-7200),
        ),
    ]

    func accessMe() async throws -> LabAccess {
        fatalError("Readme demo does not call accessMe().")
    }

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        PaginatedResponse(items: sampleSessions, nextCursor: nil, hasMore: false)
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        sampleSessions[0]
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        sampleSessions[0]
    }

    func retryInitialSimulation(simulationID _: Int) async throws -> TrainerSessionDTO {
        sampleSessions[0]
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRestViewModelDTO {
        fatalError("Readme demo does not call getRuntimeState().")
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        fatalError("Readme demo does not call getControlPlaneDebug().")
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        sampleSessions[0]
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call triggerRunTick().")
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call triggerVitalsTick().")
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        fatalError("Readme demo does not call listEvents().")
    }

    func getRunSummary(simulationID _: Int) async throws -> RunSummary {
        fatalError("Readme demo does not call getRunSummary().")
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        fatalError("Readme demo does not call adjustSimulation().")
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call steerPrompt().")
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call injectInjuryEvent().")
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call injectIllnessEvent().")
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createProblem().")
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createAssessmentFinding().")
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createDiagnosticResult().")
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createResourceState().")
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createDispositionState().")
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call injectVitalEvent().")
    }

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call injectInterventionEvent().")
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        fatalError("Readme demo does not call listPresets().")
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        fatalError("Readme demo does not call createPreset().")
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        fatalError("Readme demo does not call getPreset().")
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        fatalError("Readme demo does not call updatePreset().")
    }

    func deletePreset(presetID _: Int) async throws {
        fatalError("Readme demo does not call deletePreset().")
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        fatalError("Readme demo does not call duplicatePreset().")
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        fatalError("Readme demo does not call sharePreset().")
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        fatalError("Readme demo does not call unsharePreset().")
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call applyPreset().")
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        fatalError("Readme demo does not call injuryDictionary().")
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        fatalError("Readme demo does not call interventionDictionary().")
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        fatalError("Readme demo does not call listAccounts().")
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        fatalError("Readme demo does not call updateProblemStatus().")
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        fatalError("Readme demo does not call createNoteEvent().")
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        fatalError("Readme demo does not call createAnnotation().")
    }

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        fatalError("Readme demo does not call listAnnotations().")
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        fatalError("Readme demo does not call updateScenarioBrief().")
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {
        fatalError("Readme demo does not call replayPending().")
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        fatalError("Readme demo does not call getGuardState().")
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        fatalError("Readme demo does not call sendHeartbeat().")
    }
}

private final class ReadmeDemoRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    let events = AsyncStream<ChatEventEnvelope> { _ in }
    let connectionStates = AsyncStream<ChatRealtimeConnectionState> { continuation in
        continuation.yield(.connected)
    }

    func start(simulationID _: Int, initialLastEventID _: String?) async {}
    func reconnect(simulationID _: Int, lastEventID _: String?) async {}
    func updateReplayAnchor(_: String?) async {}
    func disconnect() {}
    func send(eventType _: String, payload _: [String: JSONValue]) async {}
}

@MainActor
private final class ReadmeDemoVoiceClient: ChatVoiceRealtimeClientProtocol {
    let events = AsyncStream<ChatVoiceRealtimeEvent> { _ in }
    let connectionStates = AsyncStream<ChatVoiceConnectionState> { continuation in
        continuation.yield(.idle)
    }

    func connect(session _: ChatVoiceSession) async throws {}
    func setMuted(_: Bool) async {}
    func sendToolResult(toolCallID _: String, output _: [String: JSONValue]) async throws {}
    func disconnect() async {}
}

private struct ReadmeDemoFeedbackService: FeedbackServiceProtocol {
    func fetchFeedbackCategories() async throws -> [FeedbackCategoryDTO] {
        []
    }

    func submitFeedback(_: FeedbackCreateRequest) async throws -> FeedbackResponse {
        fatalError("The screenshot demo does not submit feedback.")
    }
}

private struct ReadmeDemoMediaLoader: ChatMediaLoading {
    func loadMediaData(for _: ChatMessageMedia) async throws -> Data {
        throw URLError(.fileDoesNotExist)
    }
}

private struct ReadmeDemoHaptics: ChatHapticFeedbackProviding {
    func play(_: ChatHapticEvent) {}
}

private struct ReadmeDemoChatService: ChatLabServiceProtocol {
    static let activeSimulation = ChatSimulation(
        id: 901,
        userID: 7,
        startTimestamp: Date().addingTimeInterval(-900),
        endTimestamp: nil,
        timeLimitSeconds: 1800,
        diagnosis: "Acute asthma exacerbation",
        chiefComplaint: "Shortness of breath after exertion",
        patientDisplayName: "Jordan Alvarez",
        patientInitials: "JA",
        status: .inProgress,
        terminalReasonCode: "",
        terminalReasonText: "",
        terminalAt: nil,
        retryable: nil,
    )

    private static let sampleSimulations = [
        activeSimulation,
        ChatSimulation(
            id: 894,
            userID: 7,
            startTimestamp: Date().addingTimeInterval(-10800),
            endTimestamp: Date().addingTimeInterval(-8400),
            timeLimitSeconds: 1800,
            diagnosis: "Community-acquired pneumonia",
            chiefComplaint: "Fever, cough, pleuritic chest pain",
            patientDisplayName: "Mina Patel",
            patientInitials: "MP",
            status: .completed,
            terminalReasonCode: "completed",
            terminalReasonText: "Simulation complete",
            terminalAt: Date().addingTimeInterval(-8400),
            retryable: false,
        ),
        ChatSimulation(
            id: 887,
            userID: 7,
            startTimestamp: Date().addingTimeInterval(-17200),
            endTimestamp: Date().addingTimeInterval(-16900),
            timeLimitSeconds: 1800,
            diagnosis: "DKA",
            chiefComplaint: "Nausea, abdominal pain, polyuria",
            patientDisplayName: "Sam Carter",
            patientInitials: "SC",
            status: .failed,
            terminalReasonCode: "feedback_generation_failed",
            terminalReasonText: "Feedback generation timed out",
            terminalAt: Date().addingTimeInterval(-16900),
            retryable: true,
        ),
    ]

    private static let patientConversation = ChatConversation(
        id: 1201,
        uuid: "demo-patient-conversation",
        simulationID: activeSimulation.id,
        conversationType: "simulated_patient",
        conversationTypeDisplay: "Patient",
        icon: "person.crop.circle",
        displayName: activeSimulation.patientDisplayName,
        displayInitials: activeSimulation.patientInitials,
        isLocked: false,
        createdAt: Date().addingTimeInterval(-900),
    )

    private static let sampleMessages = [
        ChatMessage(
            id: 1,
            simulationID: activeSimulation.id,
            conversationID: patientConversation.id,
            conversationType: patientConversation.conversationType,
            senderID: 100,
            content: "I was running when my chest tightened up. I can talk, but I feel short of breath.",
            role: "assistant",
            messageType: "text",
            timestamp: Date().addingTimeInterval(-720),
            isFromAI: true,
            displayName: activeSimulation.patientDisplayName,
            deliveryStatus: .delivered,
            deliveryErrorCode: "",
            deliveryErrorText: "",
            deliveryRetryable: false,
            deliveryRetryCount: 0,
            isRead: true,
            mediaList: [],
        ),
        ChatMessage(
            id: 2,
            simulationID: activeSimulation.id,
            conversationID: patientConversation.id,
            conversationType: patientConversation.conversationType,
            senderID: activeSimulation.userID,
            content: "Have you used your rescue inhaler today?",
            role: "user",
            messageType: "text",
            timestamp: Date().addingTimeInterval(-660),
            isFromAI: false,
            displayName: "Learner",
            deliveryStatus: .delivered,
            deliveryErrorCode: "",
            deliveryErrorText: "",
            deliveryRetryable: false,
            deliveryRetryCount: 0,
            isRead: true,
            mediaList: [],
        ),
        ChatMessage(
            id: 3,
            simulationID: activeSimulation.id,
            conversationID: patientConversation.id,
            conversationType: patientConversation.conversationType,
            senderID: 100,
            content: "Twice. It helped for a few minutes, then the tightness came back.",
            role: "assistant",
            messageType: "text",
            timestamp: Date().addingTimeInterval(-600),
            isFromAI: true,
            displayName: activeSimulation.patientDisplayName,
            deliveryStatus: .delivered,
            deliveryErrorCode: "",
            deliveryErrorText: "",
            deliveryRetryable: false,
            deliveryRetryCount: 0,
            isRead: true,
            mediaList: [],
        ),
    ]

    private static let sampleTools = [
        ChatToolState(
            name: "patient_history",
            displayName: "Patient History",
            data: [[
                "label": .string("Symptom onset"),
                "value": .string("During exertion approximately 20 minutes ago"),
            ]],
            isGeneric: false,
            checksum: "history-1",
        ),
        ChatToolState(
            name: "patient_results",
            displayName: "Patient Results",
            data: [[
                "id": .number(301),
                "result_name": .string("Peak Expiratory Flow"),
                "value": .number(240),
                "unit": .string("L/min"),
                "flag": .string("abnormal"),
                "type": .string("assessment"),
            ]],
            isGeneric: false,
            checksum: "results-1",
        ),
        ChatToolState(
            name: "simulation_metadata",
            displayName: "Simulation Details",
            data: [
                ["key": .string("Setting"), "value": .string("Urgent care")],
                ["key": .string("Difficulty"), "value": .string("Intermediate")],
            ],
            isGeneric: false,
            checksum: "metadata-1",
        ),
    ]

    func listSimulations(
        limit _: Int,
        cursor _: String?,
        status _: String?,
        query _: String?,
        searchMessages _: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        PaginatedResponse(items: Self.sampleSimulations, nextCursor: nil, hasMore: false)
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation {
        Self.sampleSimulations[0]
    }

    func getSimulation(simulationID _: Int) async throws -> ChatSimulation {
        Self.sampleSimulations[0]
    }

    func endSimulation(simulationID _: Int) async throws -> ChatSimulation {
        Self.sampleSimulations[1]
    }

    func retryInitial(simulationID _: Int) async throws -> ChatSimulation {
        Self.sampleSimulations[0]
    }

    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation {
        Self.sampleSimulations[0]
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        ChatConversationListResponse(items: [Self.patientConversation])
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        fatalError("Readme demo does not call createConversation().")
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        fatalError("Readme demo does not call getConversation().")
    }

    func listMessages(
        simulationID _: Int,
        conversationID _: Int?,
        cursor _: String?,
        order _: String,
        limit _: Int,
    ) async throws -> PaginatedResponse<ChatMessage> {
        PaginatedResponse(items: Array(Self.sampleMessages.reversed()), nextCursor: nil, hasMore: false)
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        fatalError("Readme demo does not call createMessage().")
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("Readme demo does not call retryMessage().")
    }

    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        Self.sampleMessages[0]
    }

    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        Self.sampleMessages[0]
    }

    func listEvents(simulationID _: Int, lastEventID _: String?, limit _: Int) async throws -> ChatEventReplayResponse {
        ChatEventReplayResponse(items: [], nextEventID: nil, hasMore: false)
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        ChatToolListResponse(items: Self.sampleTools)
    }

    func getTool(simulationID _: Int, toolName: String) async throws -> ChatToolState {
        Self.sampleTools.first { $0.name == toolName } ?? Self.sampleTools[0]
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        fatalError("Readme demo does not call signOrders().")
    }

    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        fatalError("Readme demo does not call submitLabOrders().")
    }

    func listModifierGroups(labType _: String) async throws -> [ModifierGroup] {
        [
            ModifierGroup(
                key: "clinical_scenario",
                label: "Clinical Scenario",
                description: "Type of clinical encounter",
                selection: ModifierSelectionConfig(mode: .single, required: false),
                modifiers: [
                    ModifierOption(
                        key: "respiratory",
                        label: "Respiratory",
                        description: "Respiratory issue",
                    ),
                ],
            ),
        ]
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        GuardStateDTO(
            guardState: "active",
            guardReason: "none",
            engineRunnable: true,
            activeElapsedSeconds: 900,
            runtimeCapSeconds: 1800,
            wallClockExpiresAt: nil,
            warnings: [],
            denial: nil,
        )
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        try await getGuardState(simulationID: Self.activeSimulation.id)
    }
}
