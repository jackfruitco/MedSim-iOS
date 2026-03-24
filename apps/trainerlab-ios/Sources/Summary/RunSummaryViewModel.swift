import Foundation
import Networking
import SharedModels

@MainActor
public final class RunSummaryViewModel: ObservableObject {
    public static let notReadyCopy = "Summary is still being prepared. Check back in a moment."

    @Published public private(set) var summary: RunSummary?
    @Published public private(set) var isLoading = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public private(set) var notReadyMessage: String?

    private let service: TrainerLabServiceProtocol
    private let simulationID: Int

    public init(service: TrainerLabServiceProtocol, simulationID: Int) {
        self.service = service
        self.simulationID = simulationID
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func load() async {
        isLoading = true
        presentableError = nil
        notReadyMessage = nil
        summary = nil
        defer { isLoading = false }

        do {
            summary = try await service.getRunSummary(simulationID: simulationID)
        } catch let APIClientError.http(statusCode, _, _) where statusCode == 404 {
            notReadyMessage = Self.notReadyCopy
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }
}
