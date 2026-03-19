import Foundation
import Networking
import SharedModels

@MainActor
public final class SessionHubViewModel: ObservableObject {
    @Published public private(set) var sessions: [TrainerSessionDTO] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var hasMore = false
    @Published public private(set) var errorMessage: String?
    @Published public var searchQuery: String = ""

    private var nextCursor: String?
    private let service: TrainerLabServiceProtocol
    private var searchDebounceTask: Task<Void, Never>?

    public init(service: TrainerLabServiceProtocol) {
        self.service = service
    }

    public func onSearchQueryChanged() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await loadSessions()
        }
    }

    public func loadSessions() async {
        isLoading = true
        errorMessage = nil
        nextCursor = nil
        defer { isLoading = false }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await service.listSessions(limit: 50, cursor: nil, status: nil, query: q.isEmpty ? nil : q)
            sessions = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadMoreSessions() async {
        guard hasMore, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await service.listSessions(limit: 50, cursor: cursor, status: nil, query: q.isEmpty ? nil : q)
            sessions.append(contentsOf: response.items)
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createSession() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let request = TrainerSessionCreateRequest(
            scenarioSpec: [
                "diagnosis": .string("Undifferentiated trauma"),
                "chief_complaint": .string("Altered mental status"),
                "tick_interval_seconds": .number(10)
            ],
            directives: "Begin with unstable vitals and evolving airway compromise.",
            modifiers: ["night-ops", "limited-resources"]
        )

        do {
            let idempotencyKey = "ios.session.create.\(UUID().uuidString.lowercased())"
            let session = try await service.createSession(request: request, idempotencyKey: idempotencyKey)
            sessions.insert(session, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
