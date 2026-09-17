import Foundation
import Networking
import SharedModels

@MainActor
public final class ChatToolsStore: ObservableObject {
    @Published public private(set) var toolsByName: [String: ChatToolState] = [:]
    @Published public private(set) var patientResults: [ChatPatientResult] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var hasLoadedTools = false
    @Published public private(set) var isSubmittingOrders = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public var stagedOrders: [String] = []
    @Published public private(set) var resultsUpdateToken: UUID?

    private let service: ChatLabServiceProtocol
    private let simulationID: Int

    public init(service: ChatLabServiceProtocol, simulationID: Int) {
        self.service = service
        self.simulationID = simulationID
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func loadTools() async {
        isLoading = true
        presentableError = nil
        defer { isLoading = false }
        do {
            let response = try await service.listTools(simulationID: simulationID, names: nil)
            apply(response.items)
            hasLoadedTools = true
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func refreshTools() async {
        guard !isLoading, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let response = try await service.listTools(simulationID: simulationID, names: nil)
            apply(response.items)
            hasLoadedTools = true
            presentableError = nil
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func stageOrder(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !stagedOrders.contains(trimmed), trimmed.count <= 30 else {
            return
        }
        stagedOrders.append(trimmed)
    }

    public func removeOrder(at indexSet: IndexSet) {
        stagedOrders.remove(atOffsets: indexSet)
    }

    public func discardStagedOrders() {
        stagedOrders.removeAll()
    }

    public func acknowledgeResultsUpdate() {
        resultsUpdateToken = nil
    }

    public func signOrders() async {
        guard !stagedOrders.isEmpty, !isSubmittingOrders else {
            return
        }
        isSubmittingOrders = true
        presentableError = nil
        defer { isSubmittingOrders = false }
        do {
            _ = try await service.signOrders(
                simulationID: simulationID,
                request: ChatSignOrdersRequest(submittedOrders: stagedOrders),
            )
            stagedOrders.removeAll()
            await refreshTools()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func toolData(_ name: String) -> [[String: JSONValue]] {
        toolsByName[name]?.data ?? []
    }

    private func apply(_ tools: [ChatToolState]) {
        let previousResultsChecksum = toolsByName["patient_results"]?.checksum
        let normalized = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        toolsByName = normalized
        patientResults = normalized["patient_results"]?.patientResults ?? []
        if let previousResultsChecksum,
           let currentResultsChecksum = normalized["patient_results"]?.checksum,
           previousResultsChecksum != currentResultsChecksum
        {
            resultsUpdateToken = UUID()
        }
    }
}
