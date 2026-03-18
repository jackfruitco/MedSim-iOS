import Foundation
import Networking
import SharedModels

@MainActor
public final class RunSummaryViewModel: ObservableObject {
    @Published public private(set) var summary: RunSummary?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let service: TrainerLabServiceProtocol
    private let simulationID: Int

    public init(service: TrainerLabServiceProtocol, simulationID: Int) {
        self.service = service
        self.simulationID = simulationID
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            summary = try await service.getRunSummary(simulationID: simulationID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
