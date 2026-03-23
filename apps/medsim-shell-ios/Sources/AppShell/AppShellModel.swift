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
    public let accountSessionStore: AccountSessionStore
    public let billingService: AppleBillingService
    public let sessionHubViewModel: SessionHubViewModel
    public let presetsViewModel: PresetsViewModel

    private let tokenStore: KeychainTokenStore
    private let mutableBaseURLProvider: MutableBaseURLProvider
    private let selectedAccountContext: SelectedAccountContext
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

        let selectedAccountContext = SelectedAccountContext()
        self.selectedAccountContext = selectedAccountContext

        let apiClient = APIClient(
            baseURLProvider: { mutableBaseURLProvider.currentURL() },
            tokenProvider: tokenStore,
            accountContextProvider: selectedAccountContext,
        )
        self.apiClient = apiClient

        let trainerService = TrainerLabService(apiClient: apiClient)
        self.trainerService = trainerService
        chatService = ChatLabService(apiClient: apiClient)

        let accountSessionStore = AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { mutableBaseURLProvider.currentURL() },
            accountContext: selectedAccountContext,
        )
        self.accountSessionStore = accountSessionStore

        billingService = AppleBillingService(
            apiClient: apiClient,
            accountSessionStore: accountSessionStore,
        )

        let commandQueue: CommandQueueStoreProtocol
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )
            let dbURL = support.appendingPathComponent("trainerlab-command-queue.sqlite")
            commandQueue = try GRDBCommandQueueStore(fileURL: dbURL)
        } catch {
            commandQueue = InMemoryCommandQueueStore()
        }
        self.commandQueue = commandQueue

        let authService = AuthService(apiClient: apiClient, tokenProvider: tokenStore)
        authViewModel = AuthViewModel(authService: authService, sessionBootstrapper: accountSessionStore)
        sessionHubViewModel = SessionHubViewModel(
            service: trainerService,
            accountUUIDProvider: { [weak accountSessionStore] in accountSessionStore?.selectedAccountUUID },
        )
        presetsViewModel = PresetsViewModel(
            service: trainerService,
            accountUUIDProvider: { [weak accountSessionStore] in accountSessionStore?.selectedAccountUUID },
        )
        bindChildPublishers()
    }

    public func makeRunSessionStore(session: TrainerSessionDTO) -> RunSessionStore {
        let sse = SSETransport(
            baseURLProvider: { self.mutableBaseURLProvider.currentURL() },
            tokenProvider: tokenStore,
            accountContextProvider: selectedAccountContext,
        )
        let polling = PollingTransport(service: trainerService)
        let realtime = RealtimeClient(sseTransport: sse, pollingTransport: polling)
        let store = RunSessionStore(
            service: trainerService,
            realtimeClient: realtime,
            commandQueue: commandQueue,
            accountUUID: accountSessionStore.selectedAccountUUID,
        )
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
            accountContextProvider: selectedAccountContext,
            service: chatService,
        )
        return ChatRunStore(
            service: chatService,
            realtimeClient: realtime,
            simulation: simulation,
        )
    }

    public func makeChatToolsStore(simulationID: Int) -> ChatToolsStore {
        ChatToolsStore(service: chatService, simulationID: simulationID)
    }

    public func syncBaseURLFromEnvironment() {
        mutableBaseURLProvider.setURL(environmentStore.baseURL)
    }

    public func resetScopedWorkspaceState() {
        sessionHubViewModel.resetForAccountChange()
        presetsViewModel.resetForAccountChange()
    }

    private func bindChildPublishers() {
        authViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        accountSessionStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        billingService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        environmentStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
