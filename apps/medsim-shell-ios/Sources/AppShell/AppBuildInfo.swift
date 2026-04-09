import Foundation

struct AppBuildInfo: Equatable {
    let version: String
    let build: String

    init(
        version: String,
        build: String,
    ) {
        self.version = AppBuildInfo.resolveValue(version)
        self.build = AppBuildInfo.resolveValue(build)
    }

    init(infoDictionary: [String: Any]?) {
        version = AppBuildInfo.resolveValue(infoDictionary?["CFBundleShortVersionString"] as? String)
        build = AppBuildInfo.resolveValue(infoDictionary?["CFBundleVersion"] as? String)
    }

    static func current(bundle: Bundle = .main) -> AppBuildInfo {
        AppBuildInfo(infoDictionary: bundle.infoDictionary)
    }

    private static func resolveValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
}
