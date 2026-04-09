import Foundation

public protocol BuildInfoServiceProtocol: Sendable {
    func fetchBuildInfo() async throws -> BuildInfoResponse
}

public struct BuildInfoService: BuildInfoServiceProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchBuildInfo() async throws -> BuildInfoResponse {
        try await apiClient.request(SystemAPI.buildInfo(), as: BuildInfoResponse.self)
    }
}
