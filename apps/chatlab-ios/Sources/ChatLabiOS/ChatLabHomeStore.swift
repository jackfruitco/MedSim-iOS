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
    @Published public private(set) var isLoadingModifierGroups = false
    @Published public private(set) var hasLoadedModifierGroups = false
    @Published public private(set) var modifierLoadError: PresentableAppError?
    @Published public private(set) var modifierValidationErrors: [String] = []
    @Published public var selectedModifiersByGroup: [String: Set<String>] = [:]

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

    public var selectedModifiers: Set<String> {
        Set(flattenSelectedModifierKeys())
    }

    public var canCreateSimulation: Bool {
        !isCreating &&
            hasLoadedModifierGroups &&
            !isLoadingModifierGroups &&
            modifierLoadError == nil
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
        guard !isLoading, !isLoadingMore else { return }
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

    public func loadModifierGroups(labType: String = "chatlab") async {
        isLoadingModifierGroups = true
        modifierLoadError = nil
        defer { isLoadingModifierGroups = false }

        do {
            modifierGroups = try await service.listModifierGroups(labType: labType)
            hasLoadedModifierGroups = true
            pruneStaleSelectedModifiers()
        } catch {
            hasLoadedModifierGroups = false
            modifierLoadError = AppErrorPresenter.present(error)
        }
    }

    public func selectSingleModifier(_ modifier: String?, in group: ModifierGroup) {
        modifierValidationErrors = []
        if let modifier, !modifier.isEmpty {
            selectedModifiersByGroup[group.key] = [modifier]
        } else {
            selectedModifiersByGroup[group.key] = []
        }
    }

    public func toggleMultipleModifier(_ modifier: String, in group: ModifierGroup) {
        modifierValidationErrors = []
        var selected = selectedModifiersByGroup[group.key] ?? []
        if selected.contains(modifier) {
            selected.remove(modifier)
        } else {
            selected.insert(modifier)
        }
        selectedModifiersByGroup[group.key] = selected
    }

    public func isModifierSelected(_ modifier: String, in group: ModifierGroup) -> Bool {
        selectedModifiersByGroup[group.key]?.contains(modifier) ?? false
    }

    public func singleSelection(in group: ModifierGroup) -> String? {
        let selected = selectedModifiersByGroup[group.key] ?? []
        return group.modifiers.first { selected.contains($0.key) }?.key
    }

    public func flattenSelectedModifierKeys() -> [String] {
        Self.flattenSelectedModifierKeys(groups: modifierGroups, selected: selectedModifiersByGroup)
    }

    public func validateModifierSelections() -> [String] {
        Self.validateModifierSelections(groups: modifierGroups, selected: selectedModifiersByGroup)
    }

    public func quickCreateSimulation() async -> ChatSimulation? {
        isCreating = true
        presentableError = nil
        modifierValidationErrors = []
        defer { isCreating = false }

        guard !isLoadingModifierGroups else {
            modifierValidationErrors = ["Modifiers are still loading."]
            return nil
        }

        guard modifierLoadError == nil else {
            presentableError = PresentableAppError(
                title: "Modifiers Unavailable",
                message: "Refresh modifiers and try again.",
                recoveryActionLabel: "Retry",
            )
            return nil
        }

        guard hasLoadedModifierGroups else {
            modifierValidationErrors = ["Modifiers are still loading."]
            return nil
        }

        let validationErrors = validateModifierSelections()
        guard validationErrors.isEmpty else {
            modifierValidationErrors = validationErrors
            return nil
        }

        do {
            let created = try await service.quickCreateSimulation(
                request: ChatQuickCreateRequest(modifiers: flattenSelectedModifierKeys()),
            )
            simulations.insert(created, at: 0)
            return created
        } catch {
            if Self.isInvalidModifierSelectionError(error) {
                presentableError = PresentableAppError(
                    title: "Invalid Modifier Selection",
                    message: "Invalid modifier selection. Refresh and try again.",
                    statusCode: 400,
                    recoveryActionLabel: "Retry",
                )
            } else {
                presentableError = AppErrorPresenter.present(error)
            }
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

    private func pruneStaleSelectedModifiers() {
        selectedModifiersByGroup = Self.prunedSelections(groups: modifierGroups, selected: selectedModifiersByGroup)
    }

    private static func prunedSelections(
        groups: [ModifierGroup],
        selected: [String: Set<String>],
    ) -> [String: Set<String>] {
        var pruned: [String: Set<String>] = [:]

        for group in groups {
            let selectedForGroup = selected[group.key] ?? []
            let validSelected = group.modifiers
                .map(\.key)
                .filter { selectedForGroup.contains($0) }

            switch group.selection.mode {
            case .single:
                if let first = validSelected.first {
                    pruned[group.key] = [first]
                }
            case .multiple:
                if !validSelected.isEmpty {
                    pruned[group.key] = Set(validSelected)
                }
            }
        }

        return pruned
    }

    private static func flattenSelectedModifierKeys(
        groups: [ModifierGroup],
        selected: [String: Set<String>],
    ) -> [String] {
        var keys: [String] = []

        for group in groups {
            let selectedForGroup = selected[group.key] ?? []
            keys.append(contentsOf: group.modifiers.map(\.key).filter { selectedForGroup.contains($0) })
        }

        return keys
    }

    private static func validateModifierSelections(
        groups: [ModifierGroup],
        selected: [String: Set<String>],
    ) -> [String] {
        var errors: [String] = []

        for group in groups {
            let selectedCount = selected[group.key]?.count ?? 0

            if group.selection.required {
                switch group.selection.mode {
                case .single where selectedCount == 0:
                    errors.append("\(group.label) is required.")
                case .multiple where selectedCount == 0:
                    errors.append("\(group.label) requires at least one selection.")
                default:
                    break
                }
            }

            if group.selection.mode == .single, selectedCount > 1 {
                errors.append("\(group.label) allows only one selection.")
            }
        }

        return errors
    }

    private static func isInvalidModifierSelectionError(_ error: Error) -> Bool {
        guard let apiError = error as? APIClientError else { return false }
        return apiError.statusCode == 400
    }
}
