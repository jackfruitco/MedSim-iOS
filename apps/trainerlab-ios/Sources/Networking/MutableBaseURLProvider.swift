import Foundation

public final class MutableBaseURLProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URL

    public init(initial: URL) {
        value = initial
    }

    public func currentURL() -> URL {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    public func setURL(_ url: URL) {
        lock.lock()
        value = url
        lock.unlock()
    }
}
