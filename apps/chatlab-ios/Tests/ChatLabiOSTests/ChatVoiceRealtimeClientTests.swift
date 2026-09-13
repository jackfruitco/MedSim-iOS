@testable import ChatLabiOS
import Foundation
import SharedModels
import XCTest

@MainActor
final class ChatVoiceRealtimeClientTests: XCTestCase {
    func testParsesUserTranscriptCompletion() throws {
        let json = """
        {
          "type": "conversation.item.input_audio_transcription.completed",
          "event_id": "event-user-1",
          "item_id": "item-user-1",
          "transcript": "I feel dizzy."
        }
        """

        let event = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse(json))

        guard case let .transcript(transcript) = event else {
            return XCTFail("Expected transcript event")
        }
        XCTAssertEqual(transcript.role, "user")
        XCTAssertEqual(transcript.transcript, "I feel dizzy.")
        XCTAssertEqual(transcript.providerItemID, "item-user-1")
        XCTAssertEqual(transcript.providerEventID, "event-user-1")
    }

    func testParsesAssistantAudioTranscriptCompletion() throws {
        let json = """
        {
          "type": "response.output_audio_transcript.done",
          "event_id": "event-assistant-1",
          "response_id": "response-1",
          "item_id": "item-assistant-1",
          "transcript": "Tell me when it started."
        }
        """

        let event = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse(json))

        guard case let .transcript(transcript) = event else {
            return XCTFail("Expected transcript event")
        }
        XCTAssertEqual(transcript.role, "assistant")
        XCTAssertEqual(transcript.providerResponseID, "response-1")
        XCTAssertEqual(transcript.providerItemID, "item-assistant-1")
        XCTAssertEqual(transcript.transcript, "Tell me when it started.")
    }

    func testParsesFunctionCallArgumentsDone() throws {
        let json = """
        {
          "type": "response.function_call_arguments.done",
          "event_id": "event-tool-1",
          "response_id": "response-1",
          "call_id": "call-1",
          "name": "sign_lab_orders",
          "arguments": "{\\"orders\\":[\\"CBC\\",\\"CMP\\"]}"
        }
        """

        let event = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse(json))

        guard case let .toolCall(toolCall) = event else {
            return XCTFail("Expected tool call event")
        }
        XCTAssertEqual(toolCall.toolCallID, "call-1")
        XCTAssertEqual(toolCall.name, "sign_lab_orders")
        XCTAssertEqual(toolCall.arguments["orders"], .array([.string("CBC"), .string("CMP")]))
        XCTAssertEqual(toolCall.providerEventID, "event-tool-1")
    }

    func testParsesOutputAudioDelta() throws {
        let audio = Data([1, 2, 3, 4]).base64EncodedString()
        let json = """
        {
          "type": "response.output_audio.delta",
          "delta": "\(audio)"
        }
        """

        let event = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse(json))

        XCTAssertEqual(event, .outputAudio(Data([1, 2, 3, 4])))
    }

    func testInvalidOutputAudioDeltaSurfacesProtocolFailure() {
        let json = """
        {
          "type": "response.output_audio.delta",
          "delta": "not-valid-base64"
        }
        """

        XCTAssertThrowsError(try ChatVoiceRealtimeEventParser.parse(json)) { error in
            XCTAssertEqual(
                error as? ChatVoiceRealtimeClientError,
                .protocolFailure(message: "Voice service returned invalid audio data."),
            )
        }
    }

    func testParsesRemoteSpeechLifecycleEvents() throws {
        let started = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse("""
        {"type":"output_audio_buffer.started"}
        """))
        let stopped = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse("""
        {"type":"response.output_audio.done"}
        """))

        XCTAssertEqual(started, .remoteSpeechStarted)
        XCTAssertEqual(stopped, .remoteSpeechStopped)
    }

    func testParsesProviderErrorWithCodeAndType() throws {
        let json = """
        {
          "type": "error",
          "error": {
            "type": "invalid_request_error",
            "code": "invalid_event",
            "message": "The event is not valid."
          }
        }
        """

        let event = try XCTUnwrap(ChatVoiceRealtimeEventParser.parse(json))

        guard case let .error(providerError) = event else {
            return XCTFail("Expected provider error event")
        }
        XCTAssertEqual(providerError.type, "invalid_request_error")
        XCTAssertEqual(providerError.code, "invalid_event")
        XCTAssertEqual(providerError.message, "The event is not valid.")
        XCTAssertEqual(providerError.displayMessage, "The event is not valid. (invalid_event)")
    }

    func testPermissionBridgeResumesWhenCallbackArrivesOffMainActor() async {
        let granted = await ChatVoicePermissionBridge.request { completion in
            DispatchQueue.global(qos: .utility).async {
                completion(true)
            }
        }

        XCTAssertTrue(granted)
    }

    func testConnectWaitsForHandshakeAndFiltersImmutableSessionFields() async throws {
        let socket = TestVoiceWebSocketTask()
        var capturedRequest: URLRequest?
        await socket.enqueue(.string("""
        {"type":"session.created"}
        """))
        await socket.enqueue(.string("""
        {"type":"session.updated"}
        """))

        let client = ChatVoiceRealtimeClient(
            makeWebSocketTask: { request in
                capturedRequest = request
                return socket
            },
            audioStartOverride: {},
            audioStopOverride: {},
        )
        let stateTask = Task { @MainActor in
            var states: [ChatVoiceConnectionState] = []
            for await state in client.connectionStates {
                states.append(state)
                if state == .live {
                    return states
                }
            }
            return states
        }

        try await client.connect(session: makeVoiceSession())
        let states = await stateTask.value

        XCTAssertTrue(states.contains(.live))
        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "OpenAI-Beta"))
        XCTAssertEqual(socket.sentMessages.count, 1)
        guard case let .string(payload) = socket.sentMessages[0],
              let object = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
              let config = object["session"] as? [String: Any]
        else {
            return XCTFail("Expected session.update payload")
        }
        XCTAssertEqual(config["type"] as? String, "realtime")
        XCTAssertNil(config["model"])
        XCTAssertEqual(config["instructions"] as? String, "Test voice session")

        await client.disconnect()
    }

    func testConnectFailsWithHandshakeTimeoutAndCleansUp() async throws {
        let socket = TestVoiceWebSocketTask()
        let client = ChatVoiceRealtimeClient(
            makeWebSocketTask: { _ in socket },
            handshakeTimeoutNanoseconds: 20_000_000,
            audioStartOverride: {},
            audioStopOverride: {},
        )

        do {
            try await client.connect(session: makeVoiceSession())
            XCTFail("Expected handshake timeout")
        } catch let error as ChatVoiceRealtimeClientError {
            XCTAssertEqual(error, .handshakeTimedOut)
            XCTAssertEqual(error.userFacingMessage, "Voice service did not respond. Please try again.")
        }

        XCTAssertEqual(socket.closeCode, .normalClosure)
    }

    private func makeVoiceSession() -> ChatVoiceSession {
        ChatVoiceSession(
            id: 501,
            uuid: "voice-session-uuid",
            simulationID: 42,
            conversationID: 3,
            status: .active,
            transport: .webSocket,
            provider: "openai",
            providerSessionID: "realtime-session-1",
            model: "gpt-realtime-test",
            voice: "verse",
            createdAt: Date(),
            updatedAt: Date(),
            endedAt: nil,
            expiresAt: Date().addingTimeInterval(300),
            realtimeURL: nil,
            callsURL: nil,
            websocketURL: "wss://api.openai.test/v1/realtime",
            clientSecret: ["value": .string("ek_test")],
            sessionConfig: [
                "type": .string("realtime"),
                "model": .string("gpt-realtime-test"),
                "instructions": .string("Test voice session"),
            ],
        )
    }
}

private actor TestVoiceMessageQueue {
    private var messages: [URLSessionWebSocketTask.Message] = []
    private var waiters: [CheckedContinuation<URLSessionWebSocketTask.Message, Error>] = []

    func enqueue(_ message: URLSessionWebSocketTask.Message) {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: message)
        } else {
            messages.append(message)
        }
    }

    func next() async throws -> URLSessionWebSocketTask.Message {
        if let message = messages.first {
            messages.removeFirst()
            return message
        }
        if Task.isCancelled {
            throw CancellationError()
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func cancelOne() {
        guard waiters.isEmpty == false else { return }
        waiters.removeFirst().resume(throwing: CancellationError())
    }
}

private final class TestVoiceWebSocketTask: ChatVoiceWebSocketTask, @unchecked Sendable {
    private let queue = TestVoiceMessageQueue()
    private var recordedMessages: [URLSessionWebSocketTask.Message] = []
    private var currentCloseCode: URLSessionWebSocketTask.CloseCode = .invalid
    private var currentCloseReason: Data?

    var sentMessages: [URLSessionWebSocketTask.Message] {
        return recordedMessages
    }

    var closeCode: URLSessionWebSocketTask.CloseCode {
        return currentCloseCode
    }

    var closeReason: Data? {
        return currentCloseReason
    }

    func enqueue(_ message: URLSessionWebSocketTask.Message) async {
        await queue.enqueue(message)
    }

    func resume() {}

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        recordedMessages.append(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withTaskCancellationHandler {
            try await queue.next()
        } onCancel: {
            Task { await queue.cancelOne() }
        }
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        currentCloseCode = closeCode
        currentCloseReason = reason
        Task { await queue.cancelOne() }
    }
}
