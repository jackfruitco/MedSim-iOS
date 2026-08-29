@testable import ChatLabiOS
import Foundation
import SharedModels
import XCTest

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
}
