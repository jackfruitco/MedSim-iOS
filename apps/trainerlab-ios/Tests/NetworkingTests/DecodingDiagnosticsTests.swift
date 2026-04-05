import Foundation
@testable import Networking
import Persistence
import SharedModels
import XCTest

// MARK: - formatDecodingError

private struct IntWrapper: Decodable { let value: Int }
private struct RequiredString: Decodable { let name: String }
private struct DateWrapper: Decodable { let at: Date }
private struct NestingInner: Decodable { let count: Int }
private struct NestingOuter: Decodable { let inner: NestingInner }

final class FormatDecodingErrorTests: XCTestCase {
    // MARK: typeMismatch

    func testTypeMismatchContainsExpectedComponents() throws {
        // "value" field is a String in JSON but expected as Int
        let json = Data(#"{"value": "not-a-number"}"#.utf8)
        let error = catchDecodingError { try JSONDecoder().decode(IntWrapper.self, from: json) }
        let formatted = formatDecodingError(error)

        XCTAssertTrue(formatted.hasPrefix("typeMismatch"), "Expected typeMismatch prefix, got: \(formatted)")
        XCTAssertTrue(formatted.contains("value"), "Expected coding path 'value', got: \(formatted)")
    }

    // MARK: keyNotFound

    func testKeyNotFoundContainsKeyNameAndPath() throws {
        // "name" field is missing entirely
        let json = Data(#"{}"#.utf8)
        let error = catchDecodingError { try JSONDecoder().decode(RequiredString.self, from: json) }
        let formatted = formatDecodingError(error)

        XCTAssertTrue(formatted.hasPrefix("keyNotFound"), "Expected keyNotFound prefix, got: \(formatted)")
        XCTAssertTrue(formatted.contains("name"), "Expected key name 'name', got: \(formatted)")
    }

    // MARK: dataCorrupted

    func testDataCorruptedContainsPath() throws {
        // Trigger dataCorrupted via a custom decoder that rejects a date string
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)",
            )
        }
        let json = Data(#"{"at": "not-a-date"}"#.utf8)
        let error = catchDecodingError { try decoder.decode(DateWrapper.self, from: json) }
        let formatted = formatDecodingError(error)

        XCTAssertTrue(formatted.hasPrefix("dataCorrupted"), "Expected dataCorrupted prefix, got: \(formatted)")
        XCTAssertTrue(formatted.contains("at"), "Expected coding path 'at', got: \(formatted)")
        XCTAssertTrue(formatted.contains("Invalid date:"), "Expected debug description in output, got: \(formatted)")
    }

    // MARK: non-DecodingError fallback

    func testNonDecodingErrorFallsBackToReflection() {
        struct SomeOtherError: Error {}
        let error = SomeOtherError()
        let formatted = formatDecodingError(error)
        // String(reflecting:) includes the type name
        XCTAssertTrue(formatted.contains("SomeOtherError"), "Expected type name in fallback, got: \(formatted)")
    }

    // MARK: nested coding path

    func testNestedCodingPathRenderedAsDotSeparated() throws {
        // "count" is a String instead of Int — produces typeMismatch at "inner.count"
        let json = Data(#"{"inner": {"count": "bad"}}"#.utf8)
        let error = catchDecodingError { try JSONDecoder().decode(NestingOuter.self, from: json) }
        let formatted = formatDecodingError(error)

        XCTAssertTrue(formatted.contains("inner.count"), "Expected dot-separated path 'inner.count', got: \(formatted)")
    }

    // MARK: root-level path

    func testRootLevelPathProducesNonEmptyResult() throws {
        // Decoding a plain Int from a JSON string produces an error at root level
        let json = Data(#""not-an-int""#.utf8)
        let error = catchDecodingError { try JSONDecoder().decode(Int.self, from: json) }
        let formatted = formatDecodingError(error)

        // Accept any non-empty output — the exact case (typeMismatch or dataCorrupted) may
        // vary by Swift version, but it must be non-empty and well-formed.
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Helper

    private func catchDecodingError(_ body: () throws -> Void) -> Error {
        do {
            try body()
            XCTFail("Expected an error to be thrown")
            return URLError(.badURL) // unreachable
        } catch {
            return error
        }
    }
}

// MARK: - bodyPreview

final class BodyPreviewTests: XCTestCase {
    func testUTF8DataUnderCapReturnedVerbatim() {
        let text = "Hello, world!"
        let data = Data(text.utf8)
        XCTAssertEqual(bodyPreview(data, maxBytes: 4096), text)
    }

    func testEmptyDataReturnsEmptyString() {
        XCTAssertEqual(bodyPreview(Data(), maxBytes: 4096), "")
    }

    func testUTF8DataOverCapTruncatesWithNotice() {
        let text = String(repeating: "a", count: 5000)
        let data = Data(text.utf8)
        let preview = bodyPreview(data, maxBytes: 4096)

        XCTAssertTrue(
            preview.hasPrefix(String(repeating: "a", count: 4096)),
            "Preview should start with the first 4096 'a' characters",
        )
        XCTAssertTrue(
            preview.contains("5000 bytes total"),
            "Preview should include total byte count, got: \(preview)",
        )
        XCTAssertTrue(
            preview.contains("showing first 4096"),
            "Preview should note the cap, got: \(preview)",
        )
    }

    func testExactlyAtCapHasNoTruncationNotice() {
        let text = String(repeating: "b", count: 100)
        let data = Data(text.utf8)
        let preview = bodyPreview(data, maxBytes: 100)

        XCTAssertEqual(preview, text, "Exactly-at-cap data should have no truncation suffix")
        XCTAssertFalse(preview.contains("bytes total"), "Should not contain truncation notice")
    }

    func testNonUTF8DataReturnsByteCountSummary() {
        // 0xFF 0xFE are not valid UTF-8 sequences
        let data = Data([0xFF, 0xFE, 0xFD, 0x00])
        let preview = bodyPreview(data, maxBytes: 4096)

        XCTAssertTrue(preview.hasPrefix("[non-UTF-8 body:"), "Expected non-UTF-8 summary, got: \(preview)")
        XCTAssertTrue(preview.contains("4 bytes"), "Expected byte count in summary, got: \(preview)")
    }

    func testCustomMaxBytesIsRespected() {
        let text = "ABCDEFGHIJ" // 10 bytes
        let data = Data(text.utf8)
        let preview = bodyPreview(data, maxBytes: 5)

        XCTAssertTrue(preview.hasPrefix("ABCDE"), "Preview should start with first 5 chars, got: \(preview)")
        XCTAssertTrue(preview.contains("10 bytes total"), "Should report full byte count, got: \(preview)")
    }
}

// MARK: - Integration: decode failure produces APIClientError.decoding

final class DecodingDiagnosticsIntegrationTests: XCTestCase {
    // Duplicated from APIClientTests.swift — kept private to this file.
    private final class URLProtocolMock: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with _: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                XCTFail("Missing URLProtocolMock.requestHandler")
                return
            }
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    override func tearDown() {
        super.tearDown()
        URLProtocolMock.requestHandler = nil
    }

    func testStateDecodeFailureThrowsAPIClientDecodingError() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        // Body is valid JSON but structurally incompatible with TrainerRestViewModelDTO
        let badBody = Data(#"{"broken": true}"#.utf8)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, badBody)
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: EmptyTokenProvider(),
            session: session,
        )

        // requiresAuth: false avoids the need for real tokens in this decode-focused test
        let endpoint = Endpoint(
            path: "/api/v1/trainerlab/simulations/1/state/",
            requiresAuth: false,
            requiresAccountContext: false,
        )

        do {
            _ = try await client.request(endpoint, as: TrainerRestViewModelDTO.self)
            XCTFail("Expected APIClientError.decoding to be thrown")
        } catch let error as APIClientError {
            if case .decoding = error {
                // Correct: a decode failure produces APIClientError.decoding.
                // The structured logger.error fires before this throw.
            } else {
                XCTFail("Expected .decoding error case, got: \(error)")
            }
        }
    }
}

private final class EmptyTokenProvider: AuthTokenProvider, @unchecked Sendable {
    func loadTokens() -> AuthTokens? { nil }
    func saveTokens(_: AuthTokens) {}
    func clearTokens() {}
}
