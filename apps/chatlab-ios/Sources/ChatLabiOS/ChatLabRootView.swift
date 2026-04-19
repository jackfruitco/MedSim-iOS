import FeedbackFeature
import Networking
import SharedModels
import SwiftUI

public struct ChatLabRootView: View {
    @StateObject private var homeStore: ChatLabHomeStore
    private let makeRunStore: (ChatSimulation) -> ChatRunStore
    private let makeToolsStore: (Int) -> ChatToolsStore
    private let feedbackService: FeedbackServiceProtocol
    private let feedbackHeaderProvider: FeedbackRequestHeaderProviding
    private let mediaLoader: ChatMediaLoading
    private let onExit: () -> Void

    @State private var selectedSimulation: ChatSimulation?

    public init(
        homeStore: ChatLabHomeStore,
        makeRunStore: @escaping (ChatSimulation) -> ChatRunStore,
        makeToolsStore: @escaping (Int) -> ChatToolsStore,
        feedbackService: FeedbackServiceProtocol,
        feedbackHeaderProvider: FeedbackRequestHeaderProviding,
        mediaLoader: ChatMediaLoading,
        onExit: @escaping () -> Void,
    ) {
        _homeStore = StateObject(wrappedValue: homeStore)
        self.makeRunStore = makeRunStore
        self.makeToolsStore = makeToolsStore
        self.feedbackService = feedbackService
        self.feedbackHeaderProvider = feedbackHeaderProvider
        self.mediaLoader = mediaLoader
        self.onExit = onExit
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let simulation = selectedSimulation {
                    ChatRunScreen(
                        simulation: simulation,
                        makeRunStore: makeRunStore,
                        makeToolsStore: makeToolsStore,
                        feedbackService: feedbackService,
                        feedbackHeaderProvider: feedbackHeaderProvider,
                        mediaLoader: mediaLoader,
                        onBack: { selectedSimulation = nil },
                    )
                } else {
                    ChatLabHomeView(
                        store: homeStore,
                        onOpenSimulation: { simulation in
                            selectedSimulation = simulation
                        },
                    )
                }
            }
            .toolbar {
                if selectedSimulation == nil {
                    ToolbarItem(placement: .automatic) {
                        Button("Main Menu", action: onExit)
                    }
                }
            }
        }
    }
}

private struct ChatRunScreen: View {
    let simulation: ChatSimulation
    let makeRunStore: (ChatSimulation) -> ChatRunStore
    let makeToolsStore: (Int) -> ChatToolsStore
    let feedbackService: FeedbackServiceProtocol
    let feedbackHeaderProvider: FeedbackRequestHeaderProviding
    let mediaLoader: ChatMediaLoading
    let onBack: () -> Void

    @StateObject private var runStore: ChatRunStore
    @StateObject private var toolsStore: ChatToolsStore

    init(
        simulation: ChatSimulation,
        makeRunStore: @escaping (ChatSimulation) -> ChatRunStore,
        makeToolsStore: @escaping (Int) -> ChatToolsStore,
        feedbackService: FeedbackServiceProtocol,
        feedbackHeaderProvider: FeedbackRequestHeaderProviding,
        mediaLoader: ChatMediaLoading,
        onBack: @escaping () -> Void,
    ) {
        self.simulation = simulation
        self.makeRunStore = makeRunStore
        self.makeToolsStore = makeToolsStore
        self.feedbackService = feedbackService
        self.feedbackHeaderProvider = feedbackHeaderProvider
        self.mediaLoader = mediaLoader
        self.onBack = onBack
        _runStore = StateObject(wrappedValue: makeRunStore(simulation))
        _toolsStore = StateObject(wrappedValue: makeToolsStore(simulation.id))
    }

    var body: some View {
        ChatRunView(
            store: runStore,
            toolsStore: toolsStore,
            feedbackService: feedbackService,
            feedbackHeaderProvider: feedbackHeaderProvider,
            mediaLoader: mediaLoader,
            onBack: onBack,
        )
    }
}
