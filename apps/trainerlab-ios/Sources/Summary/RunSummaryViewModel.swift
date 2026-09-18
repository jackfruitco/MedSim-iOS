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
    @Published public private(set) var isWaitingForDebrief = false

    private var isObserving = false

    private let service: TrainerLabServiceProtocol
    public let simulationID: Int

    public init(service: TrainerLabServiceProtocol, simulationID: Int) {
        self.service = service
        self.simulationID = simulationID
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func load() async {
        isLoading = summary == nil
        presentableError = nil
        notReadyMessage = nil
        defer { isLoading = false }

        do {
            summary = try await service.getRunSummary(simulationID: simulationID)
        } catch let APIClientError.http(statusCode, _, _) where statusCode == 404 {
            notReadyMessage = Self.notReadyCopy
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    /// Bound polling because the API does not distinguish pending from failed generation.
    public func loadUntilReady(maxAttempts: Int = 20, delayNanoseconds: UInt64 = 3_000_000_000) async {
        guard !isObserving else { return }
        isObserving = true
        isWaitingForDebrief = true
        defer {
            isObserving = false
            isWaitingForDebrief = false
        }
        for attempt in 0 ..< max(1, maxAttempts) {
            guard !Task.isCancelled else { return }
            await load()
            guard summary?.aiDebrief == nil, presentableError == nil else { return }
            if attempt + 1 < maxAttempts {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }
        }
    }
}
