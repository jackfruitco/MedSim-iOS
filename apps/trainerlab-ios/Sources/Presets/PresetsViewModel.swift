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
    @Published public private(set) var errorMessage: String?

    private var nextCursor: String?
    private let service: TrainerLabServiceProtocol

    public init(service: TrainerLabServiceProtocol) {
        self.service = service
    }

    public func loadPresets() async {
        isLoading = true
        errorMessage = nil
        nextCursor = nil
        defer { isLoading = false }

        do {
            let response = try await service.listPresets(limit: 100, cursor: nil)
            presets = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    public func createPreset(title: String, description: String, instruction: String, severity: String) async {
        isLoading = true
        errorMessage = nil
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
            errorMessage = error.localizedDescription
        }
    }

    public func duplicatePreset(id: Int) async {
        do {
            _ = try await service.duplicatePreset(presetID: id)
            await loadPresets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updatePreset(
        id: Int,
        title: String,
        description: String,
        instruction: String,
        severity: String,
        isActive: Bool,
    ) async {
        do {
            let updated = try await service.updatePreset(
                presetID: id,
                request: ScenarioInstructionUpdateRequest(
                    title: title,
                    description: description,
                    instructionText: instruction,
                    severity: severity,
                    isActive: isActive,
                ),
            )
            if let index = presets.firstIndex(where: { $0.id == id }) {
                presets[index] = updated
            } else {
                presets.insert(updated, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deletePreset(id: Int) async {
        do {
            try await service.deletePreset(presetID: id)
            presets.removeAll(where: { $0.id == id })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func applyPreset(id: Int, simulationID: Int) async {
        do {
            let request = ScenarioInstructionApplyRequest(simulationID: simulationID)
            let key = "ios.preset.apply.\(UUID().uuidString.lowercased())"
            _ = try await service.applyPreset(presetID: id, request: request, idempotencyKey: key)
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    public func sharePreset(id: Int, userID: Int) async {
        do {
            let request = ScenarioInstructionShareRequest(userID: userID, canRead: true, canEdit: false, canDelete: false, canShare: false, canDuplicate: true)
            _ = try await service.sharePreset(presetID: id, request: request)
            await loadPresets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func unsharePreset(id: Int, userID: Int) async {
        do {
            let request = ScenarioInstructionUnshareRequest(userID: userID)
            try await service.unsharePreset(presetID: id, request: request)
            await loadPresets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
