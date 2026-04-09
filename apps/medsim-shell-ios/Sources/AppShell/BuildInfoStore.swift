import Combine
import Foundation
import Networking

@MainActor
public final class BuildInfoStore: ObservableObject {
    public struct DisplayRow: Equatable, Sendable {
        public let title: String
        public let value: String
        public let usesMonospacedValue: Bool

        public init(
            title: String,
            value: String,
            usesMonospacedValue: Bool = false,
        ) {
            self.title = title
            self.value = value
            self.usesMonospacedValue = usesMonospacedValue
        }
    }

    @Published public var isExpanded = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var remoteBuildInfo: BuildInfoResponse?
    @Published public private(set) var loadFailed = false

    private let buildInfoService: BuildInfoServiceProtocol
    private let baseURLProvider: @Sendable () -> URL
    private let appBuildInfo: AppBuildInfo
    private var loadedBaseURL: String?
    private var loadingBaseURL: String?

    public init(
        buildInfoService: BuildInfoServiceProtocol,
        baseURLProvider: @escaping @Sendable () -> URL,
    ) {
        self.buildInfoService = buildInfoService
        self.baseURLProvider = baseURLProvider
        appBuildInfo = .current()
    }

    init(
        buildInfoService: BuildInfoServiceProtocol,
        baseURLProvider: @escaping @Sendable () -> URL,
        appBuildInfo: AppBuildInfo = .current(),
    ) {
        self.buildInfoService = buildInfoService
        self.baseURLProvider = baseURLProvider
        self.appBuildInfo = appBuildInfo
    }

    public var displayRows: [DisplayRow] {
        [
            DisplayRow(title: "App Version", value: appBuildInfo.version),
            DisplayRow(title: "App Build", value: appBuildInfo.build, usesMonospacedValue: true),
            DisplayRow(title: "Backend Version", value: valueOrPlaceholder(remoteBuildInfo?.backend?.version)),
            DisplayRow(
                title: "Backend Commit",
                value: shortenedCommit(remoteBuildInfo?.backend?.commit),
                usesMonospacedValue: true,
            ),
            DisplayRow(
                title: "Backend Build",
                value: valueOrPlaceholder(remoteBuildInfo?.backend?.buildTime),
                usesMonospacedValue: true,
            ),
            DisplayRow(title: "OrchestrAI", value: valueOrPlaceholder(remoteBuildInfo?.orchestrai?.version)),
        ]
    }

    public func loadIfNeeded() async {
        let baseURL = baseURLProvider().absoluteString
        if loadedBaseURL == baseURL || loadingBaseURL == baseURL {
            return
        }

        if loadedBaseURL != baseURL {
            remoteBuildInfo = nil
            loadFailed = false
        }

        loadingBaseURL = baseURL
        isLoading = true

        do {
            let buildInfo = try await buildInfoService.fetchBuildInfo()
            guard loadingBaseURL == baseURL else { return }
            remoteBuildInfo = buildInfo
            loadedBaseURL = baseURL
            loadFailed = false
        } catch {
            guard loadingBaseURL == baseURL else { return }
            remoteBuildInfo = nil
            loadedBaseURL = nil
            loadFailed = true
        }

        if loadingBaseURL == baseURL {
            loadingBaseURL = nil
            isLoading = false
        }
    }

    private func valueOrPlaceholder(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func shortenedCommit(_ commit: String?) -> String {
        let trimmed = valueOrPlaceholder(commit)
        guard trimmed != "—" else { return trimmed }
        return trimmed.count > 7 ? String(trimmed.prefix(7)) : trimmed
    }
}
