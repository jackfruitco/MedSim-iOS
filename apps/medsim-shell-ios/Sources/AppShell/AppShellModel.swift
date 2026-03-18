import Auth
import ChatLabiOS
import Combine
import Foundation
import Networking
import Persistence
import Presets
import Realtime
import Sessions
import SharedModels
import Summary

@MainActor
public final class AppShellModel: ObservableObject {
    public let environmentStore: APIEnvironmentStore
    public let authViewModel: AuthViewModel
    public let sessionHubViewModel: SessionHubViewModel
    public let presetsViewModel: PresetsViewModel

    private let tokenStore: KeychainTokenStore
    private let mutableBaseURLProvider: MutableBaseURLProvider
    private let apiClient: APIClient
    private let trainerService: TrainerLabService
    private let chatService: ChatLabService
    private let commandQueue: CommandQueueStoreProtocol
    private var cancellables = Set<AnyCancellable>()

    public init() {
        let environmentStore = APIEnvironmentStore()
        self.environmentStore = environmentStore
        let mutableBaseURLProvider = MutableBaseURLProvider(initial: environmentStore.baseURL)
        self.mutableBaseURLProvider = mutableBaseURLProvider

        let tokenStore = KeychainTokenStore()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-reset-auth") {
            tokenStore.clearTokens()
        }
        self.tokenStore = tokenStore

        let apiClient = APIClient(baseURLProvider: { mutableBaseURLProvider.currentURL() }, tokenProvider: tokenStore)
        self.apiClient = apiClient

        let trainerService = TrainerLabService(apiClient: apiClient)
        self.trainerService = trainerService
        self.chatService = ChatLabService(apiClient: apiClient)

        let commandQueue: CommandQueueStoreProtocol
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = support.appendingPathComponent("trainerlab-command-queue.sqlite")
            commandQueue = try GRDBCommandQueueStore(fileURL: dbURL)
        } catch {
            commandQueue = InMemoryCommandQueueStore()
        }
        self.commandQueue = commandQueue

        let authService = AuthService(apiClient: apiClient, tokenProvider: tokenStore)
        self.authViewModel = AuthViewModel(authService: authService, trainerService: trainerService)
        self.sessionHubViewModel = SessionHubViewModel(service: trainerService)
        self.presetsViewModel = PresetsViewModel(service: trainerService)
        bindChildPublishers()
    }

    public func makeRunSessionStore(session: TrainerSessionDTO) -> RunSessionStore {
        let sse = SSETransport(baseURLProvider: { self.mutableBaseURLProvider.currentURL() }, tokenProvider: tokenStore)
        let polling = PollingTransport(service: trainerService)
        let realtime = RealtimeClient(sseTransport: sse, pollingTransport: polling)
        let store = RunSessionStore(service: trainerService, realtimeClient: realtime, commandQueue: commandQueue)
        store.bind(session: session)
        return store
    }

    public func makeSummaryViewModel(simulationID: Int) -> RunSummaryViewModel {
        RunSummaryViewModel(service: trainerService, simulationID: simulationID)
    }

    public func makeChatLabHomeStore() -> ChatLabHomeStore {
        ChatLabHomeStore(service: chatService)
    }

    public func makeChatRunStore(simulation: ChatSimulation) -> ChatRunStore {
        let realtime = ChatRealtimeClient(
            baseURLProvider: { self.mutableBaseURLProvider.currentURL() },
            tokenProvider: tokenStore,
            service: chatService
        )
        return ChatRunStore(
            service: chatService,
            realtimeClient: realtime,
            simulation: simulation
        )
    }

    public func makeChatToolsStore(simulationID: Int) -> ChatToolsStore {
        ChatToolsStore(service: chatService, simulationID: simulationID)
    }

    public func syncBaseURLFromEnvironment() {
        mutableBaseURLProvider.setURL(environmentStore.baseURL)
    }

    private func bindChildPublishers() {
        authViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        environmentStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
