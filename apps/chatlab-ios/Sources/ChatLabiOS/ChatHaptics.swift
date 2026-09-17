import Foundation
#if canImport(UIKit)
    import UIKit
#endif

public enum ChatHapticEvent: Sendable, Equatable {
    case messageSent
    case voiceStarted
    case voiceEnded
    case resultsUpdated
    case simulationEnded
}

@MainActor
public protocol ChatHapticFeedbackProviding: Sendable {
    func play(_ event: ChatHapticEvent)
}

public struct SystemChatHaptics: ChatHapticFeedbackProviding {
    public init() {}

    public func play(_ event: ChatHapticEvent) {
        #if canImport(UIKit)
            switch event {
            case .messageSent:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .voiceStarted, .voiceEnded:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .resultsUpdated:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .simulationEnded:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        #endif
    }
}
