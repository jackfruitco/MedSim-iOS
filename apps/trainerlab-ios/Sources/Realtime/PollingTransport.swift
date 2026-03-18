import Foundation
import Networking
import SharedModels

public protocol PollingTransportProtocol: Sendable {
    func fetch(simulationID: Int, cursor: String?) async throws -> PaginatedResponse<EventEnvelope>
}

public final class PollingTransport: PollingTransportProtocol, @unchecked Sendable {
    private let service: TrainerLabServiceProtocol
    private let limit: Int

    public init(service: TrainerLabServiceProtocol, limit: Int = 50) {
        self.service = service
        self.limit = limit
    }

    public func fetch(simulationID: Int, cursor: String?) async throws -> PaginatedResponse<EventEnvelope> {
        try await service.listEvents(simulationID: simulationID, cursor: cursor, limit: limit)
    }
}
