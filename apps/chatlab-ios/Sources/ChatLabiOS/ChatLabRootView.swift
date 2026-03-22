import SharedModels
import SwiftUI

public struct ChatLabRootView: View {
    @StateObject private var homeStore: ChatLabHomeStore
    private let makeRunStore: (ChatSimulation) -> ChatRunStore
    private let makeToolsStore: (Int) -> ChatToolsStore
    private let onExit: () -> Void

    @State private var selectedSimulation: ChatSimulation?

    public init(
        homeStore: ChatLabHomeStore,
        makeRunStore: @escaping (ChatSimulation) -> ChatRunStore,
        makeToolsStore: @escaping (Int) -> ChatToolsStore,
        onExit: @escaping () -> Void,
    ) {
        _homeStore = StateObject(wrappedValue: homeStore)
        self.makeRunStore = makeRunStore
        self.makeToolsStore = makeToolsStore
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
    let onBack: () -> Void

    @StateObject private var runStore: ChatRunStore
    @StateObject private var toolsStore: ChatToolsStore

    init(
        simulation: ChatSimulation,
        makeRunStore: @escaping (ChatSimulation) -> ChatRunStore,
        makeToolsStore: @escaping (Int) -> ChatToolsStore,
        onBack: @escaping () -> Void,
    ) {
        self.simulation = simulation
        self.makeRunStore = makeRunStore
        self.makeToolsStore = makeToolsStore
        self.onBack = onBack
        _runStore = StateObject(wrappedValue: makeRunStore(simulation))
        _toolsStore = StateObject(wrappedValue: makeToolsStore(simulation.id))
    }

    var body: some View {
        ChatRunView(
            store: runStore,
            toolsStore: toolsStore,
            onBack: onBack,
        )
    }
}
