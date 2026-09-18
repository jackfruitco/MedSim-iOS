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
    private var refreshRequestedWhileBusy = false

    public init(service: ChatLabServiceProtocol, simulationID: Int) {
        self.service = service
        self.simulationID = simulationID
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func loadTools() async {
        guard !isLoading else { return }
        isLoading = true
        presentableError = nil
        do {
            let response = try await service.listTools(simulationID: simulationID, names: nil)
            apply(response.items)
            hasLoadedTools = true
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
        isLoading = false
        if refreshRequestedWhileBusy {
            refreshRequestedWhileBusy = false
            await refreshTools()
        }
    }

    public func refreshTools() async {
        guard !isLoading, !isRefreshing else {
            refreshRequestedWhileBusy = true
            return
        }
        repeat {
            refreshRequestedWhileBusy = false
            isRefreshing = true
            do {
                let response = try await service.listTools(simulationID: simulationID, names: nil)
                apply(response.items)
                hasLoadedTools = true
                presentableError = nil
            } catch {
                presentableError = AppErrorPresenter.present(error)
            }
            isRefreshing = false
        } while refreshRequestedWhileBusy
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
        let submittedOrders = stagedOrders
        do {
            _ = try await service.signOrders(
                simulationID: simulationID,
                request: ChatSignOrdersRequest(submittedOrders: submittedOrders),
            )
            stagedOrders.removeAll { submittedOrders.contains($0) }
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
        if hasLoadedTools,
           let currentResultsChecksum = normalized["patient_results"]?.checksum,
           previousResultsChecksum != currentResultsChecksum
        {
            resultsUpdateToken = UUID()
        }
    }
}
