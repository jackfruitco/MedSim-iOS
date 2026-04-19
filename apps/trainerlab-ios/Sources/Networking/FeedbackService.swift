import Foundation
#if canImport(UIKit)
    import UIKit
#endif

public protocol FeedbackRequestHeaderProviding: Sendable {
    var appVersionHeaderValue: String { get }
    var sessionIDHeaderValue: String { get }
    func requestHeaders() -> [String: String]
}

public struct FeedbackRequestHeaderProvider: FeedbackRequestHeaderProviding, Equatable, Sendable {
    public let appVersionHeaderValue: String
    public let sessionIDHeaderValue: String
    public let osVersionHeaderValue: String
    public let deviceModelHeaderValue: String

    public init(
        sessionID: String,
        appVersion: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
    ) {
        appVersionHeaderValue = appVersion ?? Self.resolveAppVersion(bundle: .main)
        sessionIDHeaderValue = sessionID
        osVersionHeaderValue = osVersion ?? Self.resolveOSVersion()
        deviceModelHeaderValue = deviceModel ?? Self.resolveDeviceModel()
    }

    public func requestHeaders() -> [String: String] {
        [
            "X-Platform": "ios",
            "X-App-Version": appVersionHeaderValue,
            "X-OS-Version": osVersionHeaderValue,
            "X-Device-Model": deviceModelHeaderValue,
            "X-Session-ID": sessionIDHeaderValue,
        ]
    }

    public static func resolveAppVersion(bundle: Bundle) -> String {
        let version = normalized(bundle.infoDictionary?["CFBundleShortVersionString"] as? String)
        let build = normalized(bundle.infoDictionary?["CFBundleVersion"] as? String)

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        case let (_, build?):
            return build
        default:
            return "unknown"
        }
    }

    public static func resolveOSVersion() -> String {
        #if canImport(UIKit)
            return UIDevice.current.systemVersion
        #else
            return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    public static func resolveDeviceModel() -> String {
        #if canImport(UIKit)
            let identifier = deviceIdentifier()
            return identifier.isEmpty ? UIDevice.current.model : identifier
        #else
            return ProcessInfo.processInfo.hostName
        #endif
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    #if canImport(UIKit)
        private static func deviceIdentifier() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafePointer(to: &systemInfo.machine) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 1) { machinePointer in
                    String(cString: machinePointer)
                }
            }
        }
    #endif
}

public protocol FeedbackServiceProtocol: Sendable {
    func fetchFeedbackCategories() async throws -> [FeedbackCategoryDTO]
    func submitFeedback(_ request: FeedbackCreateRequest) async throws -> FeedbackResponse
}

public struct FeedbackService: FeedbackServiceProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let headerProvider: FeedbackRequestHeaderProviding
    private let encoder: JSONEncoder

    public init(
        apiClient: APIClientProtocol,
        headerProvider: FeedbackRequestHeaderProviding,
    ) {
        self.apiClient = apiClient
        self.headerProvider = headerProvider
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func fetchFeedbackCategories() async throws -> [FeedbackCategoryDTO] {
        try await apiClient.request(FeedbackAPI.categories(), as: [FeedbackCategoryDTO].self)
    }

    public func submitFeedback(_ request: FeedbackCreateRequest) async throws -> FeedbackResponse {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            FeedbackAPI.create(body: body, headers: headerProvider.requestHeaders()),
            as: FeedbackResponse.self,
        )
    }
}
