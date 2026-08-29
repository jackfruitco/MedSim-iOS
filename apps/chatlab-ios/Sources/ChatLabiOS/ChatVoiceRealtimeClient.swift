import AVFoundation
import Foundation
import OSLog
import SharedModels

private let voiceLogger = Logger(subsystem: "com.jackfruit.medsim", category: "ChatVoiceRealtime")

public enum ChatVoiceConnectionState: Sendable, Equatable {
    case idle
    case requestingPermission
    case connecting
    case live
    case muted
    case ending
    case failed(message: String?)
}

public struct ChatVoiceTranscriptEvent: Sendable, Equatable {
    public let role: String
    public let transcript: String
    public let providerItemID: String?
    public let providerResponseID: String?
    public let providerEventID: String?
    public let metadata: [String: JSONValue]
}

public struct ChatVoiceToolCallEvent: Sendable, Equatable {
    public let toolCallID: String
    public let name: String
    public let arguments: [String: JSONValue]
    public let providerResponseID: String?
    public let providerEventID: String?
}

public enum ChatVoiceRealtimeEvent: Sendable, Equatable {
    case transcript(ChatVoiceTranscriptEvent)
    case toolCall(ChatVoiceToolCallEvent)
    case outputAudio(Data)
    case remoteSpeechStarted
    case remoteSpeechStopped
    case error(message: String)
}

@MainActor
public protocol ChatVoiceRealtimeClientProtocol: AnyObject {
    var events: AsyncStream<ChatVoiceRealtimeEvent> { get }
    var connectionStates: AsyncStream<ChatVoiceConnectionState> { get }

    func connect(session: ChatVoiceSession) async throws
    func setMuted(_ isMuted: Bool) async
    func sendToolResult(toolCallID: String, output: [String: JSONValue]) async throws
    func disconnect() async
}

public enum ChatVoiceRealtimeEventParser {
    public static func parse(_ text: String) throws -> ChatVoiceRealtimeEvent? {
        let data = Data(text.utf8)
        let object = try JSONDecoder().decode([String: JSONValue].self, from: data)
        guard let type = string(object["type"]) else { return nil }

        switch type {
        case "conversation.item.input_audio_transcription.completed":
            let transcript = string(object["transcript"]) ?? ""
            guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "user",
                    transcript: transcript,
                    providerItemID: string(object["item_id"]),
                    providerResponseID: nil,
                    providerEventID: string(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.output_audio_transcript.done":
            let transcript = string(object["transcript"]) ?? ""
            guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "assistant",
                    transcript: transcript,
                    providerItemID: string(object["item_id"]),
                    providerResponseID: string(object["response_id"]),
                    providerEventID: string(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.content_part.done":
            guard case let .object(part)? = object["part"],
                  string(part["type"]) == "audio",
                  let transcript = string(part["transcript"]),
                  transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "assistant",
                    transcript: transcript,
                    providerItemID: string(object["item_id"]),
                    providerResponseID: string(object["response_id"]),
                    providerEventID: string(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.function_call_arguments.done":
            guard let toolCallID = string(object["call_id"]),
                  let name = string(object["name"])
            else {
                return nil
            }
            let arguments = try decodeArguments(string(object["arguments"]) ?? "{}")
            return .toolCall(
                ChatVoiceToolCallEvent(
                    toolCallID: toolCallID,
                    name: name,
                    arguments: arguments,
                    providerResponseID: string(object["response_id"]),
                    providerEventID: string(object["event_id"]),
                ),
            )

        case "response.output_audio.delta":
            guard let base64 = string(object["delta"]),
                  let data = Data(base64Encoded: base64)
            else {
                return nil
            }
            return .outputAudio(data)

        case "output_audio_buffer.started", "response.audio.started":
            return .remoteSpeechStarted

        case "output_audio_buffer.stopped", "response.output_audio.done":
            return .remoteSpeechStopped

        case "error":
            if case let .object(error)? = object["error"] {
                return .error(message: string(error["message"]) ?? "Realtime voice reported an error.")
            }
            return .error(message: "Realtime voice reported an error.")

        default:
            return nil
        }
    }

    private static func decodeArguments(_ raw: String) throws -> [String: JSONValue] {
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return [:]
        }
        let data = Data(raw.utf8)
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    private static func string(_ value: JSONValue?) -> String? {
        guard case let .string(value)? = value else { return nil }
        return value
    }
}

@MainActor
public final class ChatVoiceRealtimeClient: NSObject, ChatVoiceRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<ChatVoiceRealtimeEvent>
    public let connectionStates: AsyncStream<ChatVoiceConnectionState>

    private let session: URLSession
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isMuted = false

    private let eventContinuation: AsyncStream<ChatVoiceRealtimeEvent>.Continuation
    private let stateContinuation: AsyncStream<ChatVoiceConnectionState>.Continuation

    public init(session: URLSession = .shared) {
        self.session = session

        var eventContinuation: AsyncStream<ChatVoiceRealtimeEvent>.Continuation!
        events = AsyncStream<ChatVoiceRealtimeEvent> { continuation in
            eventContinuation = continuation
        }
        self.eventContinuation = eventContinuation

        var stateContinuation: AsyncStream<ChatVoiceConnectionState>.Continuation!
        connectionStates = AsyncStream<ChatVoiceConnectionState> { continuation in
            stateContinuation = continuation
        }
        self.stateContinuation = stateContinuation

        super.init()
    }

    public func connect(session voiceSession: ChatVoiceSession) async throws {
        await disconnect()
        stateContinuation.yield(.requestingPermission)
        guard await requestMicrophonePermission() else {
            stateContinuation.yield(.failed(message: "Microphone access is required for voice chat."))
            throw ChatVoiceRealtimeClientError.microphonePermissionDenied
        }

        stateContinuation.yield(.connecting)
        let request = try makeProviderRequest(for: voiceSession)
        let socketTask = session.webSocketTask(with: request)
        self.socketTask = socketTask
        socketTask.resume()

        if let config = voiceSession.sessionConfig, !config.isEmpty {
            try await sendJSONObject([
                "type": "session.update",
                "session": config.mapValues(\.rawValue),
            ])
        }

        try startAudio()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
        stateContinuation.yield(.live)
    }

    public func setMuted(_ isMuted: Bool) async {
        self.isMuted = isMuted
        stateContinuation.yield(isMuted ? .muted : .live)
    }

    public func sendToolResult(toolCallID: String, output: [String: JSONValue]) async throws {
        let outputData = try JSONSerialization.data(
            withJSONObject: output.mapValues(\.rawValue),
            options: [.sortedKeys],
        )
        let outputText = String(decoding: outputData, as: UTF8.self)
        try await sendJSONObject([
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": toolCallID,
                "output": outputText,
            ],
        ])
        try await sendJSONObject([
            "type": "response.create",
        ])
    }

    public func disconnect() async {
        stateContinuation.yield(.ending)
        receiveTask?.cancel()
        receiveTask = nil
        stopAudio()
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        isMuted = false
        stateContinuation.yield(.idle)
    }

    private func makeProviderRequest(for voiceSession: ChatVoiceSession) throws -> URLRequest {
        guard let rawURL = voiceSession.websocketURL,
              var components = URLComponents(string: rawURL)
        else {
            throw ChatVoiceRealtimeClientError.missingWebSocketURL
        }
        var queryItems = components.queryItems ?? []
        if queryItems.contains(where: { $0.name == "model" }) == false {
            queryItems.append(URLQueryItem(name: "model", value: voiceSession.model))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw ChatVoiceRealtimeClientError.missingWebSocketURL
        }
        guard case let .string(secret)? = voiceSession.clientSecret?["value"], secret.isEmpty == false else {
            throw ChatVoiceRealtimeClientError.missingClientSecret
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        return request
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                guard let socketTask else { return }
                let message = try await socketTask.receive()
                let text = try text(from: message)
                if let event = try ChatVoiceRealtimeEventParser.parse(text) {
                    if case let .outputAudio(data) = event {
                        playAudio(data)
                    }
                    eventContinuation.yield(event)
                }
            } catch {
                if Task.isCancelled { return }
                voiceLogger.error("Voice realtime receive failed: \(String(describing: error), privacy: .public)")
                eventContinuation.yield(.error(message: "Voice connection failed."))
                stateContinuation.yield(.failed(message: "Voice connection failed."))
                return
            }
        }
    }

    private func text(from message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case let .string(text):
            return text
        case let .data(data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            throw ChatVoiceRealtimeClientError.unsupportedMessage
        }
    }

    private func sendAudioData(_ data: Data) async {
        guard socketTask != nil, data.isEmpty == false else { return }
        do {
            try await sendJSONObject([
                "type": "input_audio_buffer.append",
                "audio": data.base64EncodedString(),
            ])
        } catch {
            voiceLogger.error("Voice audio send failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func sendJSONObject(_ object: [String: Any]) async throws {
        guard let socketTask else {
            throw ChatVoiceRealtimeClientError.notConnected
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        let text = String(decoding: data, as: UTF8.self)
        try await socketTask.send(.string(text))
    }

    private func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        #else
            return true
        #endif
    }

    private func startAudio() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let outputFormat = ChatVoiceAudioCodec.outputFormat
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isMuted == false else { return }
                let data = ChatVoiceAudioCodec.pcm16Data(from: buffer)
                await self.sendAudioData(data)
            }
        }

        #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        #endif

        try engine.start()
        player.play()
        audioEngine = engine
        playerNode = player
    }

    private func stopAudio() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func playAudio(_ data: Data) {
        guard let playerNode, let buffer = ChatVoiceAudioCodec.audioBuffer(fromPCM16: data) else { return }
        if playerNode.isPlaying == false {
            playerNode.play()
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }
}

public enum ChatVoiceRealtimeClientError: Error, Equatable {
    case microphonePermissionDenied
    case missingWebSocketURL
    case missingClientSecret
    case notConnected
    case unsupportedMessage
}

private enum ChatVoiceAudioCodec {
    static let sampleRate: Double = 24_000
    static let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)!

    static func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0
        else {
            return Data()
        }

        let sourceFrameCount = Int(buffer.frameLength)
        let sourceSampleRate = buffer.format.sampleRate
        let sourceChannelCount = max(1, Int(buffer.format.channelCount))
        let outputFrameCount = max(
            1,
            Int((Double(sourceFrameCount) * sampleRate / max(sourceSampleRate, 1)).rounded()),
        )

        var data = Data(capacity: outputFrameCount * MemoryLayout<Int16>.size)
        for frame in 0 ..< outputFrameCount {
            let sourcePosition = sourceSampleRate > 0
                ? Double(frame) * sourceSampleRate / sampleRate
                : Double(frame)
            let sample = interpolatedSample(
                channelData: channelData,
                channelCount: sourceChannelCount,
                frameCount: sourceFrameCount,
                position: sourcePosition,
            )
            var intSample = Int16(sample * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &intSample) { data.append(contentsOf: $0) }
        }
        return data
    }

    static func audioBuffer(fromPCM16 data: Data) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount),
              let channel = buffer.int16ChannelData?[0]
        else {
            return nil
        }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
            channel.update(from: source, count: Int(frameCount))
        }
        return buffer
    }

    private static func interpolatedSample(
        channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        frameCount: Int,
        position: Double,
    ) -> Float {
        let lowerFrame = min(frameCount - 1, max(0, Int(position.rounded(.down))))
        let upperFrame = min(frameCount - 1, lowerFrame + 1)
        let fraction = Float(position - Double(lowerFrame))
        let lower = monoSample(channelData: channelData, channelCount: channelCount, frame: lowerFrame)
        let upper = monoSample(channelData: channelData, channelCount: channelCount, frame: upperFrame)
        return max(-1, min(1, lower + ((upper - lower) * fraction)))
    }

    private static func monoSample(
        channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        frame: Int,
    ) -> Float {
        guard channelCount > 1 else {
            return channelData[0][frame]
        }
        var sum: Float = 0
        for channel in 0 ..< channelCount {
            sum += channelData[channel][frame]
        }
        return sum / Float(channelCount)
    }
}
