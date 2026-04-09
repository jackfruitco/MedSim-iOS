import Foundation

public struct BuildInfoResponse: Decodable, Sendable {
    public let backend: BackendBuildInfo?
    public let orchestrai: OrchestraiBuildInfo?

    public init(
        backend: BackendBuildInfo?,
        orchestrai: OrchestraiBuildInfo?,
    ) {
        self.backend = backend
        self.orchestrai = orchestrai
    }
}

public struct BackendBuildInfo: Decodable, Sendable {
    public let version: String?
    public let commit: String?
    public let buildTime: String?

    public init(
        version: String?,
        commit: String?,
        buildTime: String?,
    ) {
        self.version = version
        self.commit = commit
        self.buildTime = buildTime
    }

    enum CodingKeys: String, CodingKey {
        case version
        case commit
        case buildTime = "build_time"
    }
}

public struct OrchestraiBuildInfo: Decodable, Sendable {
    public let version: String?

    public init(version: String?) {
        self.version = version
    }
}
