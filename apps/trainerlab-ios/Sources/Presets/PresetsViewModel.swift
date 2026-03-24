import Foundation
import Networking
import SharedModels

@MainActor
public final class PresetsViewModel: ObservableObject {
    @Published public private(set) var presets: [ScenarioInstruction] = []
    @Published public private(set) var accountResults: [AccountListUser] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var hasMore = false
    @Published public private(set) var presentableError: PresentableAppError?

    private var nextCursor: String?
    private let service: TrainerLabServiceProtocol
    private let accountUUIDProvider: () -> String?

    public init(service: TrainerLabServiceProtocol, accountUUIDProvider: @escaping () -> String? = { nil }) {
        self.service = service
        self.accountUUIDProvider = accountUUIDProvider
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func resetForAccountChange() {
        presets = []
        accountResults = []
        nextCursor = nil
        hasMore = false
        presentableError = nil
    }

    public func loadPresets() async {
        isLoading = true
        presentableError = nil
        nextCursor = nil
        defer { isLoading = false }

        do {
            let response = try await service.listPresets(limit: 100, cursor: nil)
            presets = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func loadMorePresets() async {
        guard hasMore, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await service.listPresets(limit: 100, cursor: cursor)
            presets.append(contentsOf: response.items)
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func createPreset(title: String, description: String, instruction: String, severity: String) async {
        isLoading = true
        presentableError = nil
        defer { isLoading = false }

        let request = ScenarioInstructionCreateRequest(
            title: title,
            description: description,
            instructionText: instruction,
            injuries: [],
            severity: severity,
        )

        do {
            let created = try await service.createPreset(request: request)
            presets.insert(created, at: 0)
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func duplicatePreset(id: Int) async {
        do {
            _ = try await service.duplicatePreset(presetID: id)
            await loadPresets()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func updatePreset(id: Int, request: ScenarioInstructionUpdateRequest) async {
        do {
            let updated = try await service.updatePreset(
                presetID: id,
                request: request,
            )
            if let index = presets.firstIndex(where: { $0.id == id }) {
                presets[index] = updated
            } else {
                presets.insert(updated, at: 0)
            }
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func deletePreset(id: Int) async {
        do {
            try await service.deletePreset(presetID: id)
            presets.removeAll(where: { $0.id == id })
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func applyPreset(id: Int, simulationID: Int) async {
        do {
            let request = ScenarioInstructionApplyRequest(simulationID: simulationID)
            let key = makeIdempotencyKey(scope: "preset.apply")
            _ = try await service.applyPreset(presetID: id, request: request, idempotencyKey: key)
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func searchAccounts(query: String) async {
        guard !query.isEmpty else {
            accountResults = []
            return
        }

        do {
            let response = try await service.listAccounts(query: query, cursor: nil, limit: 15)
            accountResults = response.items
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func sharePreset(id: Int, userID: Int) async {
        do {
            let request = ScenarioInstructionShareRequest(userID: userID, canRead: true, canEdit: false, canDelete: false, canShare: false, canDuplicate: true)
            _ = try await service.sharePreset(presetID: id, request: request)
            await loadPresets()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func unsharePreset(id: Int, userID: Int) async {
        do {
            let request = ScenarioInstructionUnshareRequest(userID: userID)
            try await service.unsharePreset(presetID: id, request: request)
            await loadPresets()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    private func makeIdempotencyKey(scope: String) -> String {
        let accountFragment = accountUUIDProvider()?
            .split(separator: "-")
            .first
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0.lowercased() } ?? "global"
        return "ios.\(scope).\(accountFragment).\(UUID().uuidString.lowercased())"
    }
}
