import Combine
import Foundation

#if os(iOS)
    @preconcurrency import AVFoundation
    @preconcurrency import Speech
#endif

/// Owns only capture resources. No networking or scenario mutation is possible here.
@MainActor
final class VoiceActionCapture: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var errorMessage: String?
    private var generation = UUID()
    private var limitTask: Task<Void, Never>?

    #if os(iOS)
        private let engine = AVAudioEngine()
        private var request: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
        private var hasTap = false
        private var ownsAudioSession = false
        private var interruptionObserver: NSObjectProtocol?
    #endif

    func start() async {
        guard !isRecording, !isStarting else { return }
        cancel()
        transcript = ""
        errorMessage = nil
        isStarting = true
        let token = generation
        #if os(iOS)
            let authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            guard token == generation else { return }
            guard authorization == .authorized else {
                fail("Speech recognition is unavailable. Use the action picker or enable speech access in Settings.")
                return
            }
            let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
            guard token == generation else { return }
            guard microphoneAllowed else {
                fail("Microphone access is unavailable. You can still use the action picker.")
                return
            }
            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable,
                  recognizer.supportsOnDeviceRecognition
            else {
                fail("On-device dictation is unavailable for this language. Use the action picker.")
                return
            }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
                try session.setActive(true)
                ownsAudioSession = true
                let audioRequest = SFSpeechAudioBufferRecognitionRequest()
                audioRequest.shouldReportPartialResults = true
                audioRequest.requiresOnDeviceRecognition = true
                request = audioRequest
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else {
                    fail("No microphone is available. Use the action picker.")
                    return
                }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    audioRequest.append(buffer)
                }
                hasTap = true
                recognitionTask = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
                    let text = result?.bestTranscription.formattedString
                    let finished = result?.isFinal == true
                    let failed = error != nil
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        if let text { self.transcript = String(text.prefix(2000)) }
                        if failed || finished {
                            self.stop()
                            if failed { self.errorMessage = "Dictation stopped. Review the captured text or try again." }
                        }
                    }
                }
                interruptionObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification, object: nil, queue: .main,
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.stop() }
                }
                engine.prepare()
                try engine.start()
                isStarting = false
                isRecording = true
                limitTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    self?.stop()
                }
            } catch {
                fail("Dictation could not start. Use the action picker or try again.")
            }
        #else
            fail("Voice capture is available on iPhone and iPad. Use the action picker here.")
        #endif
    }

    /// Freeze the latest visible partial result. Late callbacks cannot change reviewed text.
    func stop() {
        generation = UUID()
        isStarting = false
        isRecording = false
        limitTask?.cancel()
        limitTask = nil
        #if os(iOS)
            engine.stop()
            if hasTap {
                engine.inputNode.removeTap(onBus: 0)
                hasTap = false
            }
            request?.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            request = nil
            if let interruptionObserver {
                NotificationCenter.default.removeObserver(interruptionObserver)
                self.interruptionObserver = nil
            }
            if ownsAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                ownsAudioSession = false
            }
        #endif
    }

    func cancel() {
        stop()
        transcript = ""
    }

    private func fail(_ message: String) {
        stop()
        errorMessage = message
    }
}
