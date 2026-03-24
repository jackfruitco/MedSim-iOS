import Foundation
import Networking
import SharedModels

@MainActor
public final class ChatLabHomeStore: ObservableObject {
    @Published public private(set) var simulations: [ChatSimulation] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var isCreating = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public var searchQuery = ""
    @Published public var includeMessageSearch = false
    @Published public private(set) var modifierGroups: [ModifierGroup] = []
    @Published public var selectedModifiers = Set<String>()

    private let service: ChatLabServiceProtocol
    private var nextCursor: String?
    private var hasMore = true
    private var autoRefreshTask: Task<Void, Never>?

    public init(service: ChatLabServiceProtocol) {
        self.service = service
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public func loadInitial() async {
        isLoading = true
        presentableError = nil
        defer { isLoading = false }

        do {
            let page = try await service.listSimulations(
                limit: 20,
                cursor: nil,
                status: nil,
                query: searchQuery,
                searchMessages: includeMessageSearch,
            )
            simulations = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func loadMoreIfNeeded(current simulation: ChatSimulation) async {
        guard hasMore, !isLoadingMore, !isLoading, simulation.id == simulations.last?.id else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.listSimulations(
                limit: 20,
                cursor: nextCursor,
                status: nil,
                query: searchQuery,
                searchMessages: includeMessageSearch,
            )
            simulations.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func refresh() async {
        do {
            let page = try await service.listSimulations(
                limit: 20,
                cursor: nil,
                status: nil,
                query: searchQuery,
                searchMessages: includeMessageSearch,
            )
            simulations = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func search() async {
        await loadInitial()
    }

    public func loadModifierGroups() async {
        do {
            modifierGroups = try await service.listModifierGroups(groups: ["ClinicalScenario", "ClinicalDuration"])
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func toggleModifier(_ modifier: String) {
        if selectedModifiers.contains(modifier) {
            selectedModifiers.remove(modifier)
        } else {
            selectedModifiers.insert(modifier)
        }
    }

    public func quickCreateSimulation() async -> ChatSimulation? {
        isCreating = true
        presentableError = nil
        defer { isCreating = false }

        do {
            let created = try await service.quickCreateSimulation(
                request: ChatQuickCreateRequest(modifiers: selectedModifiers.sorted()),
            )
            simulations.insert(created, at: 0)
            return created
        } catch {
            presentableError = AppErrorPresenter.present(error)
            return nil
        }
    }

    public func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
}
