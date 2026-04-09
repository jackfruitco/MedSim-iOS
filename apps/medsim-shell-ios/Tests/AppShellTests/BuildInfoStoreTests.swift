@testable import AppShell
import Foundation
import Networking
import XCTest

private enum MockBuildInfoError: Error {
    case failed
}

private final class MockBuildInfoService: BuildInfoServiceProtocol, @unchecked Sendable {
    var results: [Result<BuildInfoResponse, Error>] = []
    var fetchCount = 0
    var suspendNextFetch = false
    private var continuation: CheckedContinuation<Void, Never>?

    func fetchBuildInfo() async throws -> BuildInfoResponse {
        fetchCount += 1

        if suspendNextFetch {
            suspendNextFetch = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        guard !results.isEmpty else {
            throw MockBuildInfoError.failed
        }
        return try results.removeFirst().get()
    }

    func resumeFetch() {
        continuation?.resume()
        continuation = nil
    }
}

private final class URLBox: @unchecked Sendable {
    var url: URL

    init(url: URL) {
        self.url = url
    }
}

private func makeURL(_ value: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
    try XCTUnwrap(URL(string: value), file: file, line: line)
}

final class AppBuildInfoTests: XCTestCase {
    func testInitFromInfoDictionaryResolvesValues() {
        let buildInfo = AppBuildInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "45",
            ],
        )

        XCTAssertEqual(buildInfo.version, "1.2.3")
        XCTAssertEqual(buildInfo.build, "45")
    }

    func testInitFromInfoDictionaryFallsBackSafely() {
        let buildInfo = AppBuildInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "   ",
                "CFBundleVersion": "",
            ],
        )

        XCTAssertEqual(buildInfo.version, "—")
        XCTAssertEqual(buildInfo.build, "—")
    }
}

@MainActor
final class BuildInfoStoreTests: XCTestCase {
    func testLoadIfNeededPopulatesRemoteBuildInfoOnSuccess() async throws {
        let exampleURL = try makeURL("https://example.com")
        let service = MockBuildInfoService()
        service.results = [
            .success(
                BuildInfoResponse(
                    backend: BackendBuildInfo(
                        version: "0.14.2",
                        commit: "abc1234def5678",
                        buildTime: "2026-04-09T17:12:44Z",
                    ),
                    orchestrai: OrchestraiBuildInfo(version: "1.9.0"),
                ),
            ),
        ]
        let store = BuildInfoStore(
            buildInfoService: service,
            baseURLProvider: { exampleURL },
            appBuildInfo: AppBuildInfo(version: "2.0.0", build: "88"),
        )

        await store.loadIfNeeded()

        XCTAssertFalse(store.isLoading)
        XCTAssertFalse(store.loadFailed)
        XCTAssertEqual(store.remoteBuildInfo?.backend?.version, "0.14.2")
        XCTAssertEqual(store.remoteBuildInfo?.backend?.commit, "abc1234def5678")
        XCTAssertEqual(store.remoteBuildInfo?.orchestrai?.version, "1.9.0")
        XCTAssertEqual(store.displayRows.map(\.value), [
            "2.0.0",
            "88",
            "0.14.2",
            "abc1234",
            "2026-04-09T17:12:44Z",
            "1.9.0",
        ])
        XCTAssertEqual(service.fetchCount, 1)
    }

    func testLoadIfNeededMarksFailureWithoutBlockingLocalRows() async throws {
        let exampleURL = try makeURL("https://example.com")
        let service = MockBuildInfoService()
        service.results = [.failure(MockBuildInfoError.failed)]
        let store = BuildInfoStore(
            buildInfoService: service,
            baseURLProvider: { exampleURL },
            appBuildInfo: AppBuildInfo(version: "2.0.0", build: "88"),
        )

        await store.loadIfNeeded()

        XCTAssertFalse(store.isLoading)
        XCTAssertTrue(store.loadFailed)
        XCTAssertNil(store.remoteBuildInfo)
        XCTAssertEqual(store.displayRows.map(\.value), [
            "2.0.0",
            "88",
            "—",
            "—",
            "—",
            "—",
        ])
    }

    func testDisclosureStateCanToggle() throws {
        let exampleURL = try makeURL("https://example.com")
        let store = BuildInfoStore(
            buildInfoService: MockBuildInfoService(),
            baseURLProvider: { exampleURL },
            appBuildInfo: AppBuildInfo(version: "2.0.0", build: "88"),
        )

        XCTAssertFalse(store.isExpanded)
        store.isExpanded.toggle()
        XCTAssertTrue(store.isExpanded)
    }

    func testDisplayRowsStayStableWhenBackendValuesAreMissing() throws {
        let exampleURL = try makeURL("https://example.com")
        let store = BuildInfoStore(
            buildInfoService: MockBuildInfoService(),
            baseURLProvider: { exampleURL },
            appBuildInfo: AppBuildInfo(version: "2.0.0", build: "88"),
        )

        XCTAssertEqual(store.displayRows.map(\.title), [
            "App Version",
            "App Build",
            "Backend Version",
            "Backend Commit",
            "Backend Build",
            "OrchestrAI",
        ])
        XCTAssertEqual(store.displayRows.map(\.value), [
            "2.0.0",
            "88",
            "—",
            "—",
            "—",
            "—",
        ])
    }

    func testChangingBaseURLClearsStaleRowsAndFetchesAgain() async throws {
        let service = MockBuildInfoService()
        service.results = [
            .success(
                BuildInfoResponse(
                    backend: BackendBuildInfo(
                        version: "0.14.2",
                        commit: "abc1234def5678",
                        buildTime: "2026-04-09T17:12:44Z",
                    ),
                    orchestrai: OrchestraiBuildInfo(version: "1.9.0"),
                ),
            ),
            .success(
                BuildInfoResponse(
                    backend: BackendBuildInfo(
                        version: "0.15.0",
                        commit: "def5678abc1234",
                        buildTime: "2026-04-10T07:30:00Z",
                    ),
                    orchestrai: OrchestraiBuildInfo(version: "1.10.0"),
                ),
            ),
        ]
        let initialURL = try makeURL("https://one.example.com")
        let urlBox = URLBox(url: initialURL)
        let store = BuildInfoStore(
            buildInfoService: service,
            baseURLProvider: { urlBox.url },
            appBuildInfo: AppBuildInfo(version: "2.0.0", build: "88"),
        )

        await store.loadIfNeeded()
        XCTAssertEqual(store.displayRows[2].value, "0.14.2")

        service.suspendNextFetch = true
        let updatedURL = try makeURL("https://two.example.com")
        urlBox.url = updatedURL

        let loadTask = Task {
            await store.loadIfNeeded()
        }
        await Task.yield()

        XCTAssertTrue(store.isLoading)
        XCTAssertNil(store.remoteBuildInfo)
        XCTAssertEqual(store.displayRows[2].value, "—")

        service.resumeFetch()
        await loadTask.value

        XCTAssertFalse(store.isLoading)
        XCTAssertFalse(store.loadFailed)
        XCTAssertEqual(store.displayRows.map(\.value), [
            "2.0.0",
            "88",
            "0.15.0",
            "def5678",
            "2026-04-10T07:30:00Z",
            "1.10.0",
        ])
        XCTAssertEqual(service.fetchCount, 2)
    }
}
