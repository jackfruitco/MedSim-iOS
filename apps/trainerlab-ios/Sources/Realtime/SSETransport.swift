import Foundation
import OSLog
import Persistence
import SharedModels

private let logger = Logger(subsystem: "com.jackfruit.medsim", category: "TrainerSSE")

public enum SSEStreamItem: Sendable {
    case event(EventEnvelope)
    case keepAlive
}

public protocol SSETransportProtocol: Sendable {
    func stream(simulationID: Int, cursor: String?) -> AsyncThrowingStream<SSEStreamItem, Error>
}

private actor SSEFreshnessTracker {
    private var lastSignalAt = Date()
    private var staleTriggered = false

    func markSignal() {
        lastSignalAt = Date()
    }

    func shouldTriggerStale(threshold: TimeInterval) -> Bool {
        guard !staleTriggered else {
            return false
        }
        if Date().timeIntervalSince(lastSignalAt) > threshold {
            staleTriggered = true
            return true
        }
        return false
    }

    func didTriggerStale() -> Bool {
        staleTriggered
    }
}

public final class SSETransport: SSETransportProtocol, @unchecked Sendable {
    private let baseURLProvider: () -> URL
    private let tokenProvider: AuthTokenProvider
    private let session: URLSession
    private let decoder: JSONDecoder
    private let staleThresholdSeconds: TimeInterval

    public init(
        baseURLProvider: @escaping () -> URL,
        tokenProvider: AuthTokenProvider,
        session: URLSession = .shared,
        staleThresholdSeconds: TimeInterval = 45,
    ) {
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider
        self.session = session
        self.staleThresholdSeconds = staleThresholdSeconds

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        self.decoder = decoder
    }

    public func stream(simulationID: Int, cursor: String?) -> AsyncThrowingStream<SSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            let freshness = SSEFreshnessTracker()
            let task = Task {
                do {
                    let request = try await makeRequest(simulationID: simulationID, cursor: cursor)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }

                    var dataLines: [String] = []
                    var currentEventType: String?

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            break
                        }

                        if line.hasPrefix(":") {
                            await freshness.markSignal()
                            continuation.yield(.keepAlive)
                            continue
                        }

                        if line.isEmpty {
                            let isHeartbeat = currentEventType == "heartbeat"
                            if isHeartbeat {
                                await freshness.markSignal()
                                continuation.yield(.keepAlive)
                            } else if !dataLines.isEmpty {
                                let payload = dataLines.joined(separator: "\n")
                                if let event = try parseEvent(dataString: payload) {
                                    await freshness.markSignal()
                                    continuation.yield(.event(event))
                                }
                            }
                            dataLines.removeAll(keepingCapacity: true)
                            currentEventType = nil
                            continue
                        }

                        if line.hasPrefix("event:") {
                            currentEventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            continue
                        }

                        if line.hasPrefix("data:") {
                            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataLines.append(value)
                        }
                    }

                    if await freshness.didTriggerStale() {
                        continuation.finish(throwing: URLError(.timedOut))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    if await freshness.didTriggerStale() {
                        continuation.finish(throwing: URLError(.timedOut))
                    } else if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            let watchdog = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if await freshness.shouldTriggerStale(threshold: staleThresholdSeconds) {
                        task.cancel()
                        return
                    }
                }
            }

            continuation.onTermination = { _ in
                watchdog.cancel()
                task.cancel()
            }
        }
    }

    private func makeRequest(simulationID: Int, cursor: String?) async throws -> URLRequest {
        guard let tokens = tokenProvider.loadTokens() else {
            throw URLError(.userAuthenticationRequired)
        }

        let base = baseURLProvider()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = "/api/v1/trainerlab/simulations/\(simulationID)/events/stream/"
        if let cursor {
            components.queryItems = [URLQueryItem(name: "cursor", value: cursor)]
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Correlation-ID")
        return request
    }

    private func parseEvent(dataString: String) throws -> EventEnvelope? {
        guard let data = dataString.data(using: .utf8) else {
            logger.error("Dropping trainer SSE event because payload was not valid UTF-8")
            return nil
        }
        do {
            return try decoder.decode(EventEnvelope.self, from: data)
        } catch {
            logger.error(
                "Failed to decode trainer SSE event: \(error.localizedDescription, privacy: .public). Payload prefix: \(String(dataString.prefix(256)), privacy: .public)",
            )
            throw error
        }
    }

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
