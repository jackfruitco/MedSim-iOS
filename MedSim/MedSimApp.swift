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
        Group {
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
}

private enum ReadmeScreenshotScreen: String {
    case auth
    case trainerHub = "trainer-hub"
    case chatLab = "chat-lab"

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
        }
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
            await MainActor.run {
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

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRuntimeStateOut {
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
}

private struct ReadmeDemoChatService: ChatLabServiceProtocol {
    private let sampleSimulations = [
        ChatSimulation(
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
        ),
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

    func listSimulations(
        limit _: Int,
        cursor _: String?,
        status _: String?,
        query _: String?,
        searchMessages _: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        PaginatedResponse(items: sampleSimulations, nextCursor: nil, hasMore: false)
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation {
        sampleSimulations[0]
    }

    func getSimulation(simulationID _: Int) async throws -> ChatSimulation {
        sampleSimulations[0]
    }

    func endSimulation(simulationID _: Int) async throws -> ChatSimulation {
        sampleSimulations[1]
    }

    func retryInitial(simulationID _: Int) async throws -> ChatSimulation {
        sampleSimulations[0]
    }

    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation {
        sampleSimulations[0]
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        fatalError("Readme demo does not call listConversations().")
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
        fatalError("Readme demo does not call listMessages().")
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        fatalError("Readme demo does not call createMessage().")
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("Readme demo does not call retryMessage().")
    }

    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("Readme demo does not call getMessage().")
    }

    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        fatalError("Readme demo does not call markMessageRead().")
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<ChatEventEnvelope> {
        fatalError("Readme demo does not call listEvents().")
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        fatalError("Readme demo does not call listTools().")
    }

    func getTool(simulationID _: Int, toolName _: String) async throws -> ChatToolState {
        fatalError("Readme demo does not call getTool().")
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        fatalError("Readme demo does not call signOrders().")
    }

    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        fatalError("Readme demo does not call submitLabOrders().")
    }

    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] {
        []
    }
}
