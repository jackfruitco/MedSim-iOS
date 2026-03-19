import SharedModels
import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ChatRunView: View {
    @ObservedObject private var store: ChatRunStore
    @ObservedObject private var toolsStore: ChatToolsStore
    private let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showToolsSheet = false
    @State private var stagedOrderText = ""
    @State private var expandedToolSections = Set<ChatToolsSection>()
    @State private var lastToolLayoutMode: ChatRunLayoutMode?
    @State private var isKeyboardPresented = false

    public init(
        store: ChatRunStore,
        toolsStore: ChatToolsStore,
        onBack: @escaping () -> Void
    ) {
        self.store = store
        self.toolsStore = toolsStore
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = ChatRunLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass
            )
            let chromeMode = ChatRunChromeMode.resolve(isKeyboardPresented: isKeyboardPresented)

            Group {
                if layoutMode == .padWorkspace {
                    padWorkspace(chromeMode: chromeMode)
                } else {
                    compactMessengerPanel(layoutMode: layoutMode, chromeMode: chromeMode)
                        .sheet(isPresented: $showToolsSheet) {
                            NavigationStack {
                                toolsPanel(layoutMode: layoutMode)
                                    .navigationTitle("Tools")
                            }
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                        }
                }
            }
            .onAppear {
                syncExpandedToolSections(for: layoutMode)
            }
            .onChange(of: layoutMode) { _, newValue in
                syncExpandedToolSections(for: newValue)
            }
        }
        .task {
            store.start()
            await toolsStore.loadTools()
        }
        .onDisappear {
            store.stop()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                store.refreshAfterForegroundOrReconnect()
            }
        }
        .onChange(of: store.toolRefreshToken) { _, _ in
            Task { await toolsStore.refreshTools() }
        }
        .modifier(ChatInlineNavigationTitleModifier())
        .modifier(ChatKeyboardStateModifier(isKeyboardPresented: $isKeyboardPresented))
        .modifier(ChatKeyboardNavigationBarModifier(isKeyboardPresented: isKeyboardPresented))
    }

    private func padWorkspace(chromeMode: ChatRunChromeMode) -> some View {
        NavigationSplitView {
            toolsPanel(layoutMode: .padWorkspace)
                .navigationTitle("Tools")
        } detail: {
            Group {
                if store.showsInitialGenerationFailureScreen {
                    initialGenerationFailureState(layoutMode: .padWorkspace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .background(Color.secondary.opacity(0.06))
                } else {
                    VStack(spacing: chromeMode == .keyboardCollapsed ? 6 : 8) {
                        if chromeMode == .standard {
                            padActionBar
                            regularFailureBanners
                        }
                        conversationTabs(layoutMode: .padWorkspace)
                        conversationDivider(horizontalPadding: 0)
                        messageTimeline(layoutMode: .padWorkspace, chromeMode: chromeMode)
                        awaitingReplyWarning(horizontalPadding: 0)
                        typingIndicator(horizontalPadding: 0)
                        composer(layoutMode: .padWorkspace)
                    }
                    .frame(maxWidth: 920, maxHeight: .infinity, alignment: .top)
                    .padding(chromeMode == .keyboardCollapsed ? 8 : 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color.secondary.opacity(0.06))
                }
            }
            .navigationTitle(store.simulation.patientDisplayName)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Back", action: onBack)
                }
            }
        }
    }

    private func compactMessengerPanel(layoutMode: ChatRunLayoutMode, chromeMode: ChatRunChromeMode) -> some View {
        Group {
            if store.showsInitialGenerationFailureScreen {
                initialGenerationFailureState(layoutMode: layoutMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, horizontalInset(for: layoutMode))
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    if chromeMode == .standard {
                        compactStatusStrip(layoutMode: layoutMode)
                        compactFailureBanners
                    }
                    conversationTabs(layoutMode: layoutMode)
                        .padding(.top, chromeMode == .keyboardCollapsed ? 0 : 4)
                    conversationDivider(horizontalPadding: horizontalInset(for: layoutMode))
                        .padding(.top, chromeMode == .keyboardCollapsed ? 1 : 3)
                    messageTimeline(layoutMode: layoutMode, chromeMode: chromeMode)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 6) {
                        awaitingReplyWarning(horizontalPadding: horizontalInset(for: layoutMode))
                        typingIndicator(horizontalPadding: horizontalInset(for: layoutMode))
                        composer(layoutMode: layoutMode)
                    }
                    .padding(.horizontal, horizontalInset(for: layoutMode))
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle(store.simulation.patientDisplayName)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Back", action: onBack)
            }
            ToolbarItem(placement: .automatic) {
                Button("Tools") {
                    showToolsSheet = true
                }
            }
            ToolbarItem(placement: .automatic) {
                if store.simulation.status == .inProgress {
                    Menu {
                        Button(role: .destructive) {
                            store.endSimulation()
                        } label: {
                            Label("End Simulation", systemImage: "stop.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var padActionBar: some View {
        HStack(spacing: 12) {
            if store.activeConversationLocked {
                statusChip("Read Only", systemImage: "lock.fill", tint: .secondary)
            }

            Spacer()

            if store.simulation.status == .inProgress {
                Button("End Simulation") {
                    store.endSimulation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private var regularFailureBanners: some View {
        VStack(spacing: 10) {
            if let failure = store.simulationFailureText, store.showsInitialGenerationFailureScreen == false {
                failureBanner(
                    title: "Simulation failed",
                    text: failure,
                    retryable: store.simulationRetryable,
                    retryAction: { store.retryInitialSimulation() },
                    compact: false
                )
            }

            if let failure = store.feedbackFailureText {
                failureBanner(
                    title: "Feedback generation failed",
                    text: failure,
                    retryable: store.feedbackRetryable,
                    retryAction: { store.retryFeedback() },
                    compact: false
                )
            }
        }
    }

    private var compactFailureBanners: some View {
        VStack(spacing: 6) {
            if let failure = store.simulationFailureText, store.showsInitialGenerationFailureScreen == false {
                failureBanner(
                    title: "Simulation failed",
                    text: failure,
                    retryable: store.simulationRetryable,
                    retryAction: { store.retryInitialSimulation() },
                    compact: true
                )
            }

            if let failure = store.feedbackFailureText {
                failureBanner(
                    title: "Feedback failed",
                    text: failure,
                    retryable: store.feedbackRetryable,
                    retryAction: { store.retryFeedback() },
                    compact: true
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func compactStatusStrip(layoutMode: ChatRunLayoutMode) -> some View {
        HStack(spacing: 8) {
            if store.activeConversationLocked {
                statusChip("Read Only", systemImage: "lock.fill", tint: .secondary)
            }

            Spacer()
        }
        .padding(.horizontal, horizontalInset(for: layoutMode))
        .padding(.top, 4)
    }

    private func statusChip(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func conversationDivider(horizontalPadding: CGFloat) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 1)
            .padding(.horizontal, horizontalPadding)
    }

    private func conversationTabs(layoutMode: ChatRunLayoutMode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: layoutMode == .padWorkspace ? 10 : 8) {
                ForEach(store.conversations) { conversation in
                    Button {
                        store.switchConversation(conversation.id)
                    } label: {
                        HStack(spacing: 6) {
                            Text(conversation.displayName)
                            if let unread = store.unreadByConversation[conversation.id], unread > 0 {
                                Text("\(unread)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .font(tabFont(for: layoutMode).weight(store.activeConversationID == conversation.id ? .semibold : .regular))
                        .padding(.horizontal, layoutMode == .padWorkspace ? 14 : 10)
                        .padding(.vertical, layoutMode == .padWorkspace ? 8 : 6)
                        .background(
                            store.activeConversationID == conversation.id
                                ? Color.blue.opacity(0.18)
                                : Color.secondary.opacity(0.08)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, layoutMode == .padWorkspace ? 0 : horizontalInset(for: layoutMode))
        }
    }

    private func messageTimeline(layoutMode: ChatRunLayoutMode, chromeMode: ChatRunChromeMode) -> some View {
        VStack(spacing: 8) {
            if store.hasMoreByConversation[store.activeConversationID ?? -1] == true {
                Button {
                    Task { await store.loadOlderMessages() }
                } label: {
                    if store.isOlderLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Load Older Messages")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        LazyVStack(alignment: .leading, spacing: layoutMode == .padWorkspace ? 12 : 8) {
                            ForEach(store.activeMessages) { item in
                                ChatBubble(item: item, layoutMode: layoutMode) {
                                    store.retry(item)
                                }
                            }
                        }
                        .frame(maxWidth: messageColumnWidth(for: layoutMode), alignment: .leading)
                        .padding(.horizontal, layoutMode == .padWorkspace ? 0 : horizontalInset(for: layoutMode))
                        .padding(.vertical, 4)
                        Spacer(minLength: 0)
                    }
                }
                .onChange(of: store.activeMessages.count) { _, _ in
                    if let last = store.activeMessages.last?.id {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(layoutMode == .padWorkspace ? (chromeMode == .keyboardCollapsed ? 8 : 12) : 0)
        .background(layoutMode == .padWorkspace ? chatSystemBackgroundColor() : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: layoutMode == .padWorkspace ? 18 : 0, style: .continuous))
        .accessibilityIdentifier("chat-message-timeline")
    }

    @ViewBuilder
    private func typingIndicator(horizontalPadding: CGFloat) -> some View {
        if !store.activeTypingUsers.isEmpty {
            HStack {
                Text("\(store.activeTypingUsers.joined(separator: ", ")) typing...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, horizontalPadding)
        }
    }

    @ViewBuilder
    private func awaitingReplyWarning(horizontalPadding: CGFloat) -> some View {
        if let warningText = store.activeAwaitingReplyWarningText {
            VStack(alignment: .leading, spacing: 8) {
                Text(warningText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Button("Refresh Status") {
                        store.refreshAwaitingReplyStatus()
                    }
                    .buttonStyle(.bordered)

                    Button("Reconnect") {
                        store.reconnectRealtimeAndRefresh()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.orange.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, horizontalPadding)
        }
    }

    private func composer(layoutMode: ChatRunLayoutMode) -> some View {
        HStack {
            HStack(spacing: 8) {
                TextField(
                    store.activeConversationLocked ? "This conversation is read-only" : "Message",
                    text: $store.draftText,
                    axis: .vertical
                )
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .disabled(store.activeConversationLocked)
                .onChange(of: store.draftText) { _, _ in
                    store.notifyTypingChanged()
                }

                Button {
                    store.sendDraft()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.activeConversationLocked ||
                    store.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .accessibilityLabel("Send message")
            }
            .padding(layoutMode == .padWorkspace ? 14 : 0)
            .background(layoutMode == .padWorkspace ? chatSystemBackgroundColor() : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: layoutMode == .padWorkspace ? messageColumnWidth(for: layoutMode) : .infinity)
        .frame(maxWidth: .infinity)
    }

    private func failureBanner(
        title: String,
        text: String,
        retryable: Bool,
        retryAction: @escaping () -> Void,
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font((compact ? Font.caption : .subheadline).bold())
            Text(text)
                .font(compact ? .caption : .footnote)
                .lineLimit(compact ? 2 : nil)
            if retryable {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 8 : 10)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func initialGenerationFailureState(layoutMode: ChatRunLayoutMode) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(layoutMode == .padWorkspace ? .system(size: 44) : .system(size: 36))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Simulation failed")
                    .font(layoutMode == .padWorkspace ? .title2.bold() : .headline)
                Text(store.simulationFailureText ?? "Initial patient generation failed.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420)

            VStack(spacing: 10) {
                if store.simulationRetryable {
                    Button("Try Again") {
                        store.retryInitialSimulation()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Back to Simulations", action: onBack)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(layoutMode == .padWorkspace ? 24 : 16)
        .background(
            RoundedRectangle(cornerRadius: layoutMode == .padWorkspace ? 24 : 18, style: .continuous)
                .fill(chatSystemBackgroundColor())
        )
    }

    private func toolsPanel(layoutMode: ChatRunLayoutMode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layoutMode == .padWorkspace ? 14 : 12) {
                toolsHeader(layoutMode: layoutMode)
                toolSection(.patientHistory, layoutMode: layoutMode) {
                    PatientHistoryRows(rows: toolsStore.toolData("patient_history"))
                }
                toolSection(.patientResults, layoutMode: layoutMode) {
                    ToolDataRows(rows: toolsStore.toolData("patient_results"))
                }
                if simulationHasEnded {
                    toolSection(.simulationFeedback, layoutMode: layoutMode) {
                        ToolDataRows(rows: toolsStore.toolData("simulation_feedback"))
                    }
                }
                toolSection(.simulationMetadata, layoutMode: layoutMode) {
                    SimulationMetadataRows(rows: toolsStore.toolData("simulation_metadata"))
                }
                toolSection(.requestLabs, layoutMode: layoutMode) {
                    requestLabsSection(layoutMode: layoutMode)
                }
            }
            .padding(layoutMode == .padWorkspace ? 16 : 12)
        }
        .safeAreaInset(edge: .bottom) {
            if layoutMode != .padWorkspace {
                signOrdersFooter
            }
        }
        .refreshable {
            await toolsStore.refreshTools()
        }
        .background(Color.secondary.opacity(0.04))
    }

    private func toolsHeader(layoutMode: ChatRunLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Continue with Stitch") {
                store.createStitchConversationIfNeeded()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.simulation.status == .inProgress)

            if layoutMode == .padWorkspace {
                Text("Orders, patient context, and feedback stay pinned here while the chat remains readable in the detail pane.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestLabsSection(layoutMode: ChatRunLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if layoutMode == .padWorkspace {
                HStack(spacing: 10) {
                    requestLabsField
                    addOrderButton
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    requestLabsField
                    addOrderButton
                }
            }

            if !toolsStore.stagedOrders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Orders")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(toolsStore.stagedOrders.enumerated()), id: \.offset) { index, order in
                        HStack(spacing: 8) {
                            Text(order)
                                .font(.footnote)
                            Spacer()
                            Button(role: .destructive) {
                                toolsStore.removeOrder(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if let errorMessage = toolsStore.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var requestLabsField: some View {
        TextField("Request lab or imaging order", text: $stagedOrderText)
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit {
                stageCurrentOrder()
            }
    }

    private var addOrderButton: some View {
        Button("Add Order") {
            stageCurrentOrder()
        }
        .buttonStyle(.borderedProminent)
        .disabled(stagedOrderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var signOrdersFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !toolsStore.stagedOrders.isEmpty {
                Text("\(toolsStore.stagedOrders.count) order\(toolsStore.stagedOrders.count == 1 ? "" : "s") ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await toolsStore.signOrders() }
            } label: {
                if toolsStore.isSubmittingOrders {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Submit Orders")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(toolsStore.stagedOrders.isEmpty || toolsStore.isSubmittingOrders)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func toolSection<Content: View>(
        _ section: ChatToolsSection,
        layoutMode: ChatRunLayoutMode,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedToolSections.contains(section)

        return VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            Button {
                toggle(section)
            } label: {
                HStack(spacing: 10) {
                    Text(section.title)
                        .font(layoutMode == .padWorkspace ? .headline : .subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(Color.secondary.opacity(0.12))

                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(layoutMode == .padWorkspace ? 12 : 11)
        .background(chatSystemBackgroundColor())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private func toggle(_ section: ChatToolsSection) {
        if expandedToolSections.contains(section) {
            expandedToolSections.remove(section)
        } else {
            expandedToolSections.insert(section)
        }
    }

    private func syncExpandedToolSections(for layoutMode: ChatRunLayoutMode) {
        guard lastToolLayoutMode != layoutMode else {
            return
        }
        expandedToolSections = Set(
            ChatToolsSection.allCases.filter { $0.defaultExpanded(for: layoutMode) }
        )
        lastToolLayoutMode = layoutMode
    }

    private func stageCurrentOrder() {
        let trimmed = stagedOrderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        toolsStore.stageOrder(trimmed)
        stagedOrderText = ""
    }

    private func tabFont(for layoutMode: ChatRunLayoutMode) -> Font {
        switch layoutMode {
        case .compactMessenger:
            return .caption
        case .widePhoneMessenger:
            return .subheadline
        case .padWorkspace:
            return .subheadline
        }
    }

    private func horizontalInset(for layoutMode: ChatRunLayoutMode) -> CGFloat {
        switch layoutMode {
        case .compactMessenger:
            return 10
        case .widePhoneMessenger:
            return 14
        case .padWorkspace:
            return 0
        }
    }

    private func messageColumnWidth(for layoutMode: ChatRunLayoutMode) -> CGFloat {
        switch layoutMode {
        case .compactMessenger:
            return 560
        case .widePhoneMessenger:
            return 620
        case .padWorkspace:
            return 760
        }
    }

    private var simulationHasEnded: Bool {
        store.simulation.status != .inProgress
    }
}

private struct ChatKeyboardStateModifier: ViewModifier {
    @Binding var isKeyboardPresented: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardPresented = false
            }
        #else
        content
        #endif
    }
}

private struct ChatInlineNavigationTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

private struct ChatKeyboardNavigationBarModifier: ViewModifier {
    let isKeyboardPresented: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar(isKeyboardPresented ? .hidden : .visible, for: .navigationBar)
        #else
        content
        #endif
    }
}

private struct ChatBubble: View {
    let item: ChatMessageItem
    let layoutMode: ChatRunLayoutMode
    let retryAction: () -> Void

    var body: some View {
        HStack {
            if item.isFromSelf {
                Spacer(minLength: layoutMode == .padWorkspace ? 120 : 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !item.isFromSelf {
                    Text(item.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                if !item.content.isEmpty {
                    Text(item.content)
                        .font(.body)
                }
                if !item.mediaList.isEmpty {
                    mediaStrip
                }
                HStack(spacing: 8) {
                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !item.isFromSelf && !item.isRead {
                        Text("Unread")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    if item.isFromSelf {
                        Text(item.deliveryStatus.rawValue.capitalized)
                            .font(.caption2.bold())
                            .foregroundStyle(statusColor(item.deliveryStatus))
                        if item.deliveryStatus == .failed, item.retryable {
                            Button("Retry", action: retryAction)
                                .font(.caption2.bold())
                        }
                    }
                }
                if let errorText = item.errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(layoutMode == .padWorkspace ? 12 : 10)
            .frame(maxWidth: bubbleWidth(for: layoutMode), alignment: .leading)
            .background(item.isFromSelf ? Color.blue.opacity(0.18) : Color.gray.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .id(item.id)

            if !item.isFromSelf {
                Spacer(minLength: layoutMode == .padWorkspace ? 120 : 40)
            }
        }
    }

    private func bubbleWidth(for layoutMode: ChatRunLayoutMode) -> CGFloat {
        switch layoutMode {
        case .compactMessenger:
            return 320
        case .widePhoneMessenger:
            return 420
        case .padWorkspace:
            return 620
        }
    }

    @ViewBuilder
    private var mediaStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(item.mediaList.prefix(3)) { media in
                VStack(alignment: .leading, spacing: 4) {
                    AsyncImage(url: URL(string: media.thumbnailURL.isEmpty ? media.url : media.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(ProgressView().controlSize(.small))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !media.description.isEmpty {
                        Text(media.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statusColor(_ status: DeliveryStatus) -> Color {
        switch status {
        case .sending:
            return .secondary
        case .sent:
            return .blue
        case .delivered:
            return .green
        case .failed:
            return .red
        }
    }
}

private func chatSystemBackgroundColor() -> Color {
    #if canImport(UIKit)
    Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
    Color(nsColor: .windowBackgroundColor)
    #else
    Color.white
    #endif
}

private struct ToolDataRows: View {
    let rows: [[String: JSONValue]]
    var hiddenKeys: Set<String> = ["db_pk"]

    var body: some View {
        if rows.isEmpty {
            Text("No data yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let visibleKeys = row.keys.sorted().filter { !hiddenKeys.contains($0) }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleKeys, id: \.self) { key in
                            HStack(alignment: .top) {
                                Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption.bold())
                                Spacer()
                                Text(render(row[key] ?? .null))
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func render(_ value: JSONValue) -> String {
        switch value {
        case let .string(text):
            return text
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(flag):
            return flag ? "Yes" : "No"
        case let .array(values):
            return values.map(render).joined(separator: ", ")
        case let .object(dict):
            return dict.map { "\($0.key): \(render($0.value))" }.joined(separator: "; ")
        case .null:
            return "-"
        }
    }
}

private struct PatientHistoryRows: View {
    let rows: [[String: JSONValue]]

    var body: some View {
        if rows.isEmpty {
            Text("No data yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        if let summary = row["summary"] {
                            Text(render(summary))
                                .font(.subheadline.weight(.semibold))
                        }
                        if let value = row["value"] {
                            Text(render(value))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func render(_ value: JSONValue) -> String {
        switch value {
        case let .string(text):
            return text
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(flag):
            return flag ? "Yes" : "No"
        case let .array(values):
            return values.map(render).joined(separator: ", ")
        case let .object(dict):
            return dict.map { "\($0.key): \(render($0.value))" }.joined(separator: "; ")
        case .null:
            return "-"
        }
    }
}

private struct SimulationMetadataRows: View {
    let rows: [[String: JSONValue]]

    var body: some View {
        if rows.isEmpty {
            Text("No data yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(prettyKey(row["key"].map(render) ?? "Unknown"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row["value"].map(render) ?? "-")
                            .font(.footnote)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func prettyKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func render(_ value: JSONValue) -> String {
        switch value {
        case let .string(text):
            return text
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(flag):
            return flag ? "Yes" : "No"
        case let .array(values):
            return values.map(render).joined(separator: ", ")
        case let .object(dict):
            return dict.map { "\($0.key): \(render($0.value))" }.joined(separator: "; ")
        case .null:
            return "-"
        }
    }
}
