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

public struct ChatVoiceProviderError: Sendable, Equatable {
    public let type: String?
    public let code: String?
    public let message: String

    public init(type: String? = nil, code: String? = nil, message: String) {
        self.type = type
        self.code = code
        self.message = message
    }

    public var displayMessage: String {
        if let code, code.isEmpty == false {
            return "\(message) (\(code))"
        }
        return message
    }
}

public enum ChatVoiceRealtimeEvent: Sendable, Equatable {
    case transcript(ChatVoiceTranscriptEvent)
    case toolCall(ChatVoiceToolCallEvent)
    case outputAudio(Data)
    case remoteSpeechStarted
    case remoteSpeechStopped
    case error(ChatVoiceProviderError)
}

private func decodeVoiceObject(_ text: String) throws -> [String: JSONValue] {
    try JSONDecoder().decode([String: JSONValue].self, from: Data(text.utf8))
}

private func voiceString(_ value: JSONValue?) -> String? {
    guard case let .string(value)? = value else { return nil }
    return value
}

private func voiceProviderError(from object: [String: JSONValue]) -> ChatVoiceProviderError {
    guard case let .object(error)? = object["error"] else {
        return ChatVoiceProviderError(message: "Realtime voice reported an error.")
    }
    return ChatVoiceProviderError(
        type: voiceString(error["type"]),
        code: voiceString(error["code"]),
        message: voiceString(error["message"]) ?? "Realtime voice reported an error.",
    )
}

private func makeVoiceInputTap(
    continuation: AsyncStream<Data>.Continuation,
) -> AVAudioNodeTapBlock {
    { buffer, _ in
        let data = ChatVoiceAudioCodec.pcm16Data(from: buffer)
        if data.isEmpty == false {
            continuation.yield(data)
        }
    }
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

protocol ChatVoiceWebSocketTask: AnyObject, Sendable {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    var closeCode: URLSessionWebSocketTask.CloseCode { get }
    var closeReason: Data? { get }
}

extension URLSessionWebSocketTask: ChatVoiceWebSocketTask {}

enum ChatVoicePermissionBridge {
    static func request() async -> Bool {
        #if os(iOS)
            return await request { completion in
                AVAudioSession.sharedInstance().requestRecordPermission(completion)
            }
        #else
            return true
        #endif
    }

    static func request(
        register: @Sendable (@escaping @Sendable (Bool) -> Void) -> Void,
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            register { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

public enum ChatVoiceRealtimeEventParser {
    public static func parse(_ text: String) throws -> ChatVoiceRealtimeEvent? {
        let object = try decodeVoiceObject(text)
        guard let type = voiceString(object["type"]) else { return nil }

        switch type {
        case "conversation.item.input_audio_transcription.completed":
            let transcript = voiceString(object["transcript"]) ?? ""
            guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "user",
                    transcript: transcript,
                    providerItemID: voiceString(object["item_id"]),
                    providerResponseID: nil,
                    providerEventID: voiceString(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.output_audio_transcript.done":
            let transcript = voiceString(object["transcript"]) ?? ""
            guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "assistant",
                    transcript: transcript,
                    providerItemID: voiceString(object["item_id"]),
                    providerResponseID: voiceString(object["response_id"]),
                    providerEventID: voiceString(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.content_part.done":
            guard case let .object(part)? = object["part"],
                  voiceString(part["type"]) == "audio",
                  let transcript = voiceString(part["transcript"]),
                  transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            else {
                return nil
            }
            return .transcript(
                ChatVoiceTranscriptEvent(
                    role: "assistant",
                    transcript: transcript,
                    providerItemID: voiceString(object["item_id"]),
                    providerResponseID: voiceString(object["response_id"]),
                    providerEventID: voiceString(object["event_id"]),
                    metadata: ["provider_event_type": .string(type)],
                ),
            )

        case "response.function_call_arguments.done":
            guard let toolCallID = voiceString(object["call_id"]),
                  let name = voiceString(object["name"])
            else {
                return nil
            }
            let arguments = try decodeArguments(voiceString(object["arguments"]) ?? "{}")
            return .toolCall(
                ChatVoiceToolCallEvent(
                    toolCallID: toolCallID,
                    name: name,
                    arguments: arguments,
                    providerResponseID: voiceString(object["response_id"]),
                    providerEventID: voiceString(object["event_id"]),
                ),
            )

        case "response.output_audio.delta":
            guard let base64 = voiceString(object["delta"]),
                  let data = Data(base64Encoded: base64)
            else {
                throw ChatVoiceRealtimeClientError.protocolFailure(
                    message: "Voice service returned invalid audio data.",
                )
            }
            return .outputAudio(data)

        case "output_audio_buffer.started", "response.audio.started":
            return .remoteSpeechStarted

        case "output_audio_buffer.stopped", "response.output_audio.done":
            return .remoteSpeechStopped

        case "error":
            return .error(voiceProviderError(from: object))

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

}

@MainActor
public final class ChatVoiceRealtimeClient: NSObject, ChatVoiceRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<ChatVoiceRealtimeEvent>
    public let connectionStates: AsyncStream<ChatVoiceConnectionState>

    private let makeWebSocketTask: (URLRequest) -> any ChatVoiceWebSocketTask
    private var socketTask: (any ChatVoiceWebSocketTask)?
    private var receiveTask: Task<Void, Never>?
    private var inputAudioTask: Task<Void, Never>?
    private var inputAudioContinuation: AsyncStream<Data>.Continuation?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isMuted = false
    private var hasReportedTerminalFailure = false

    private let eventContinuation: AsyncStream<ChatVoiceRealtimeEvent>.Continuation
    private let stateContinuation: AsyncStream<ChatVoiceConnectionState>.Continuation
    private let handshakeTimeoutNanoseconds: UInt64
    private let audioStartOverride: (() throws -> Void)?
    private let audioStopOverride: (() -> Void)?

    public init(session: URLSession = .shared) {
        makeWebSocketTask = { session.webSocketTask(with: $0) }

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
        handshakeTimeoutNanoseconds = 10_000_000_000
        audioStartOverride = nil
        audioStopOverride = nil

        super.init()
    }

    init(
        makeWebSocketTask: @escaping (URLRequest) -> any ChatVoiceWebSocketTask,
        handshakeTimeoutNanoseconds: UInt64 = 10_000_000_000,
        audioStartOverride: (() throws -> Void)? = nil,
        audioStopOverride: (() -> Void)? = nil,
    ) {
        self.makeWebSocketTask = makeWebSocketTask
        self.handshakeTimeoutNanoseconds = handshakeTimeoutNanoseconds
        self.audioStartOverride = audioStartOverride
        self.audioStopOverride = audioStopOverride

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
        hasReportedTerminalFailure = false
        stateContinuation.yield(.requestingPermission)
        guard await ChatVoicePermissionBridge.request() else {
            stateContinuation.yield(.failed(message: "Microphone access is required for voice chat."))
            throw ChatVoiceRealtimeClientError.microphonePermissionDenied
        }

        stateContinuation.yield(.connecting)
        do {
            let request = try makeProviderRequest(for: voiceSession)
            let socketTask = makeWebSocketTask(request)
            self.socketTask = socketTask
            socketTask.resume()

            try await awaitSessionCreated()

            let config = sanitizedSessionConfig(voiceSession.sessionConfig)
            if config.isEmpty == false {
                try await sendJSONObject([
                    "type": "session.update",
                    "session": config.mapValues(\.rawValue),
                ])
                try await awaitSessionUpdated()
            }

            try startAudio()
            receiveTask = Task { [weak self] in
                await self?.receiveLoop()
            }
            stateContinuation.yield(.live)
        } catch {
            let connectionError = normalizedConnectionError(error)
            surfaceFailure(connectionError)
            throw connectionError
        }
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
        guard let outputText = String(bytes: outputData, encoding: .utf8) else {
            throw ChatVoiceRealtimeClientError.invalidUTF8
        }
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
        cleanupTransport()
        isMuted = false
        hasReportedTerminalFailure = false
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
                        try playAudio(data)
                    }
                    if case let .error(providerError) = event {
                        surfaceFailure(ChatVoiceRealtimeClientError.providerError(providerError))
                        return
                    }
                    eventContinuation.yield(event)
                }
            } catch {
                if Task.isCancelled {
                    return
                }
                surfaceFailure(error)
                return
            }
        }
    }

    private func text(from message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case let .string(text):
            return text
        case let .data(data):
            guard let text = String(bytes: data, encoding: .utf8) else {
                throw ChatVoiceRealtimeClientError.invalidUTF8
            }
            return text
        @unknown default:
            throw ChatVoiceRealtimeClientError.unsupportedMessage
        }
    }

    private func sendAudioData(_ data: Data) async throws {
        guard socketTask != nil, data.isEmpty == false else { return }
        try await sendJSONObject([
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString(),
        ])
    }

    private func sendJSONObject(_ object: [String: Any]) async throws {
        guard let socketTask else {
            throw ChatVoiceRealtimeClientError.notConnected
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw ChatVoiceRealtimeClientError.invalidUTF8
        }
        try await socketTask.send(.string(text))
    }

    private func awaitSessionCreated() async throws {
        while true {
            switch try await receiveHandshakeEvent() {
            case .sessionCreated:
                return
            case .sessionUpdated:
                continue
            case let .providerError(providerError):
                throw ChatVoiceRealtimeClientError.providerError(providerError)
            case .ignored:
                continue
            }
        }
    }

    private func awaitSessionUpdated() async throws {
        while true {
            switch try await receiveHandshakeEvent() {
            case .sessionUpdated:
                return
            case .sessionCreated:
                continue
            case let .providerError(providerError):
                throw ChatVoiceRealtimeClientError.providerError(providerError)
            case .ignored:
                continue
            }
        }
    }

    private enum HandshakeEvent {
        case sessionCreated
        case sessionUpdated
        case providerError(ChatVoiceProviderError)
        case ignored
    }

    private func receiveHandshakeEvent() async throws -> HandshakeEvent {
        let text = try await receiveTextWithTimeout()
        let object = try decodeVoiceObject(text)
        guard let type = voiceString(object["type"]) else {
            throw ChatVoiceRealtimeClientError.protocolFailure(message: "Voice service returned an invalid event.")
        }
        switch type {
        case "session.created":
            return .sessionCreated
        case "session.updated":
            return .sessionUpdated
        case "error":
            return .providerError(voiceProviderError(from: object))
        default:
            return .ignored
        }
    }

    private func receiveTextWithTimeout() async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { [weak self] in
                guard let self else {
                    throw ChatVoiceRealtimeClientError.notConnected
                }
                return try await self.receiveText()
            }
            group.addTask { [handshakeTimeoutNanoseconds] in
                try await Task.sleep(nanoseconds: handshakeTimeoutNanoseconds)
                throw ChatVoiceRealtimeClientError.handshakeTimedOut
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func receiveText() async throws -> String {
        guard let socketTask else {
            throw ChatVoiceRealtimeClientError.notConnected
        }
        return try text(from: await socketTask.receive())
    }

    private func sanitizedSessionConfig(_ config: [String: JSONValue]?) -> [String: JSONValue] {
        var sanitized = config ?? [:]
        sanitized["type"] = .string("realtime")
        sanitized.removeValue(forKey: "model")
        return sanitized
    }

    private func normalizedConnectionError(_ error: Error) -> ChatVoiceRealtimeClientError {
        if let error = error as? ChatVoiceRealtimeClientError {
            return error
        }
        if let closeCode = socketTask?.closeCode, closeCode != .invalid {
            let reason = socketTask?.closeReason.flatMap { String(data: $0, encoding: .utf8) }
            return .socketClosed(code: closeCode.rawValue, reason: reason)
        }
        if let urlError = error as? URLError {
            let message: String
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                message = "Voice connection is unavailable. Check your connection and try again."
            case .userAuthenticationRequired, .userCancelledAuthentication, .secureConnectionFailed:
                message = "Voice authentication failed. Please start again."
            default:
                message = "Voice connection failed. Please try again."
            }
            return .transportFailure(message: message)
        }
        return .transportFailure(message: "The voice connection closed unexpectedly.")
    }

    private func cleanupTransport() {
        receiveTask?.cancel()
        receiveTask = nil
        stopAudio()
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
    }

    private func startAudio() throws {
        if let audioStartOverride {
            try audioStartOverride()
            return
        }

        #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try? audioSession.setPreferredSampleRate(ChatVoiceAudioCodec.sampleRate)
            try audioSession.setActive(true)
        #endif

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let outputFormat = ChatVoiceAudioCodec.outputFormat
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        var inputAudioContinuation: AsyncStream<Data>.Continuation!
        let inputAudioStream = AsyncStream<Data> { continuation in
            inputAudioContinuation = continuation
        }
        self.inputAudioContinuation = inputAudioContinuation
        inputAudioTask = Task { @MainActor [weak self] in
            for await data in inputAudioStream {
                guard let self, isMuted == false else { continue }
                do {
                    try await sendAudioData(data)
                } catch {
                    surfaceFailure(error)
                    return
                }
            }
        }
        input.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: inputFormat,
            block: makeVoiceInputTap(continuation: inputAudioContinuation),
        )

        try engine.start()
        player.play()
        audioEngine = engine
        playerNode = player
    }

    private func stopAudio() {
        inputAudioContinuation?.finish()
        inputAudioContinuation = nil
        inputAudioTask?.cancel()
        inputAudioTask = nil
        if let audioStopOverride {
            audioStopOverride()
            return
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func playAudio(_ data: Data) throws {
        guard let playerNode else {
            throw ChatVoiceRealtimeClientError.protocolFailure(message: "Voice audio player is unavailable.")
        }
        guard let buffer = ChatVoiceAudioCodec.audioBuffer(fromPCM16: data) else {
            throw ChatVoiceRealtimeClientError.protocolFailure(message: "Voice service returned invalid PCM audio.")
        }
        if playerNode.isPlaying == false {
            playerNode.play()
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func surfaceFailure(_ error: Error) {
        guard hasReportedTerminalFailure == false else { return }
        hasReportedTerminalFailure = true
        let connectionError = normalizedConnectionError(error)
        voiceLogger.error(
            "Voice realtime failed: \(connectionError.logDescription, privacy: .public)",
        )
        cleanupTransport()
        switch connectionError {
        case let .providerError(providerError):
            eventContinuation.yield(.error(providerError))
        default:
            eventContinuation.yield(
                .error(
                    ChatVoiceProviderError(
                        type: "client_error",
                        message: connectionError.userFacingMessage,
                    ),
                ),
            )
        }
        stateContinuation.yield(.failed(message: connectionError.userFacingMessage))
    }
}

public enum ChatVoiceRealtimeClientError: Error, Equatable, Sendable {
    case microphonePermissionDenied
    case missingWebSocketURL
    case missingClientSecret
    case notConnected
    case unsupportedMessage
    case invalidUTF8
    case handshakeTimedOut
    case providerError(ChatVoiceProviderError)
    case socketClosed(code: Int, reason: String?)
    case transportFailure(message: String)
    case protocolFailure(message: String)

    public var userFacingMessage: String {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required for voice chat."
        case .missingWebSocketURL, .missingClientSecret:
            "Voice session setup is incomplete. Please start again."
        case .notConnected:
            "Voice is not connected. Please start again."
        case .unsupportedMessage, .invalidUTF8, .protocolFailure:
            "Voice service returned an unexpected response. Please start again."
        case .handshakeTimedOut:
            "Voice service did not respond. Please try again."
        case let .providerError(providerError):
            providerError.displayMessage
        case let .socketClosed(code, _):
            if code == URLSessionWebSocketTask.CloseCode.normalClosure.rawValue {
                "Voice connection ended."
            } else {
                "Voice connection closed unexpectedly. Please try again."
            }
        case let .transportFailure(message):
            message.isEmpty ? "Voice connection failed. Check your connection and try again." : message
        }
    }

    fileprivate var logDescription: String {
        switch self {
        case let .socketClosed(code, reason):
            "socket_closed code=\(code) reason=\(reason ?? "none")"
        case let .providerError(providerError):
            "provider_error type=\(providerError.type ?? "unknown") code=\(providerError.code ?? "none") message=\(providerError.message)"
        case let .transportFailure(message):
            "transport_failure message=\(message)"
        case let .protocolFailure(message):
            "protocol_failure message=\(message)"
        default:
            String(describing: self)
        }
    }
}

private enum ChatVoiceAudioCodec {
    static let sampleRate: Double = 24000
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
