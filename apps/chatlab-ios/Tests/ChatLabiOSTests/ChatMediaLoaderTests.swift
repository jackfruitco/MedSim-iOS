@testable import ChatLabiOS
import Foundation
import Networking
import XCTest

private final class RecordingAuthorizedResourceLoader: AuthorizedResourceLoading, @unchecked Sendable {
    var base = URL(fileURLWithPath: "/")
    var dataByURL: [URL: Data] = [:]
    var errorURLs = Set<URL>()
    private(set) var loadedURLs: [URL] = []

    func baseURL() async -> URL {
        base
    }

    func makeEventStreamRequest(for route: EventStreamRoute) async throws -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(route.path))
        request.httpMethod = "GET"
        return request
    }

    func loadData(from url: URL, accept _: String?, requiresAccountContext _: Bool) async throws -> Data {
        loadedURLs.append(url)
        if errorURLs.contains(url) {
            throw URLError(.badServerResponse)
        }
        guard let data = dataByURL[url] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }

    func refreshAccessToken() async throws {}
}

final class ChatMediaLoaderTests: XCTestCase {
    func testAuthenticatedLoaderFallsBackAcrossCandidatesAndCaches() async throws {
        let thumb = try XCTUnwrap(URL(string: "https://example.com/thumb.png"))
        let full = try XCTUnwrap(URL(string: "https://example.com/full.png"))

        let loader = RecordingAuthorizedResourceLoader()
        loader.base = try XCTUnwrap(URL(string: "https://example.com"))
        loader.errorURLs = [thumb]
        loader.dataByURL[full] = try imageData()

        let mediaLoader = AuthenticatedChatMediaLoader(authLoader: loader)
        let media = ChatMessageMedia(
            id: 1,
            uuid: "media-1",
            originalURL: full.absoluteString,
            thumbnailURL: thumb.absoluteString,
            url: full.absoluteString,
            mimeType: "image/png",
            description: "Portable chest x-ray",
        )

        _ = try await mediaLoader.loadMediaData(for: media)
        _ = try await mediaLoader.loadMediaData(for: media)

        XCTAssertEqual(loader.loadedURLs, [thumb, full])
    }

    private func imageData() throws -> Data {
        try XCTUnwrap(
            Data(
                base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+yF9kAAAAASUVORK5CYII=",
            ),
        )
    }
}
