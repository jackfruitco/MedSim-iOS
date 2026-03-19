import Combine
import Foundation

public enum APIEnvironmentSelection: String, CaseIterable, Codable {
    case production
    case staging
    case local
    case custom
}

public final class APIEnvironmentStore: ObservableObject {
    @Published public var selection: APIEnvironmentSelection
    @Published public var customURLString: String

    private let userDefaults: UserDefaults
    private let selectionKey = "trainerlab.environment.selection"
    private let customURLKey = "trainerlab.environment.custom"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        selection = APIEnvironmentSelection(rawValue: userDefaults.string(forKey: selectionKey) ?? "production") ?? .production
        customURLString = userDefaults.string(forKey: customURLKey) ?? "https://medsim.jackfruitco.com"
    }

    public var baseURL: URL {
        switch selection {
        case .production:
            return URL(string: "https://medsim.jackfruitco.com")!
        case .staging:
            return URL(string: "https://medsim-staging.jackfruitco.com")!
        case .local:
            return URL(string: "http://localhost")!
        case .custom:
            if let custom = URL(string: customURLString), custom.scheme == "https" {
                return custom
            }
            return URL(string: "https://medsim.jackfruitco.com")!
        }
    }

    public func persist() {
        userDefaults.set(selection.rawValue, forKey: selectionKey)
        userDefaults.set(customURLString, forKey: customURLKey)
    }
}
