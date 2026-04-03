import DesignSystem
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
    private let mediaLoader: ChatMediaLoading
    private let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showToolsSheet = false
    @State private var stagedOrderText = ""
    @State private var expandedToolSections = Set<ChatToolsSection>()
    @State private var lastToolLayoutMode: ChatRunLayoutMode?
    @State private var isKeyboardPresented = false
    @FocusState private var composerIsFocused: Bool

    public init(
        store: ChatRunStore,
        toolsStore: ChatToolsStore,
        mediaLoader: ChatMediaLoading,
        onBack: @escaping () -> Void,
    ) {
        self.store = store
        self.toolsStore = toolsStore
        self.mediaLoader = mediaLoader
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = ChatRunLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
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
        .modifier(ChatHideRunNavigationBarModifier())
        .modifier(ChatKeyboardStateModifier(isKeyboardPresented: $isKeyboardPresented))
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
                        runHeader(layoutMode: .padWorkspace)
                        if chromeMode == .standard {
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
                    runHeader(layoutMode: layoutMode)
                    if chromeMode == .standard {
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
    }

    @ViewBuilder
    private var guardBanners: some View {
        if let denial = store.guardDenial {
            guardDenialBanner(denial: denial)
        } else if let warnings = store.guardState?.warnings, !warnings.isEmpty,
                  let warning = warnings.first
        {
            guardWarningBanner(warning: warning)
        }
    }

    private func guardWarningBanner(warning: GuardSignal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(warning.displayTitle)
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text(warning.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.orange.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func guardDenialBanner(denial: GuardSignal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(denial.displayTitle)
                .font(.subheadline.bold())
                .foregroundStyle(denial.isTerminal ? .red : .orange)
            Text(denial.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(denial.isTerminal ? Color.red.opacity(0.12) : Color.orange.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var regularFailureBanners: some View {
        VStack(spacing: 10) {
            guardBanners

            if let error = store.presentableError {
                InlineAppErrorView(error: error)
            }

            if let failure = store.simulationFailureText, store.showsInitialGenerationFailureScreen == false {
                failureBanner(
                    title: "Simulation failed",
                    text: failure,
                    retryable: store.simulationRetryable,
                    retryAction: { store.retryInitialSimulation() },
                    compact: false,
                )
            }

            if let failure = store.feedbackFailureText {
                failureBanner(
                    title: "Feedback generation failed",
                    text: failure,
                    retryable: store.feedbackRetryable,
                    retryAction: { store.retryFeedback() },
                    compact: false,
                )
            }
        }
    }

    private var compactFailureBanners: some View {
        VStack(spacing: 6) {
            guardBanners

            if let error = store.presentableError {
                InlineAppErrorView(error: error)
            }

            if let failure = store.simulationFailureText, store.showsInitialGenerationFailureScreen == false {
                failureBanner(
                    title: "Simulation failed",
                    text: failure,
                    retryable: store.simulationRetryable,
                    retryAction: { store.retryInitialSimulation() },
                    compact: true,
                )
            }

            if let failure = store.feedbackFailureText {
                failureBanner(
                    title: "Feedback failed",
                    text: failure,
                    retryable: store.feedbackRetryable,
                    retryAction: { store.retryFeedback() },
                    compact: true,
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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

    private func runHeader(layoutMode: ChatRunLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                backButton
                    .frame(maxWidth: .infinity, alignment: .leading)

                patientIdentityHeader
                    .frame(maxWidth: .infinity, alignment: .center)

                headerActions(layoutMode: layoutMode)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                statusChip(
                    transportStatusTitle,
                    systemImage: transportStatusSymbol,
                    tint: transportStatusTint,
                )

                if store.activeConversationLocked {
                    statusChip("Read Only", systemImage: "lock.fill", tint: .secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, horizontalInset(for: layoutMode))
        .padding(.top, layoutMode == .padWorkspace ? 2 : 8)
        .padding(.bottom, 6)
        .background(layoutMode == .padWorkspace ? chatSystemBackgroundColor() : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: layoutMode == .padWorkspace ? 18 : 0, style: .continuous))
    }

    private var backButton: some View {
        Button(action: onBack) {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.bordered)
    }

    private var patientIdentityHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                Text(store.simulation.patientInitials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
            }
            .frame(width: 34, height: 34)

            VStack(spacing: 2) {
                Text(store.simulation.patientDisplayName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("Chat Simulation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func headerActions(layoutMode: ChatRunLayoutMode) -> some View {
        HStack(spacing: 8) {
            if layoutMode != .padWorkspace {
                Button {
                    showToolsSheet = true
                }
                label: {
                    if layoutMode == .compactMessenger {
                        Image(systemName: "slider.horizontal.3")
                    } else {
                        Text("Tools")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Tools")
            }

            if store.simulation.status == .inProgress {
                Button("End Simulation") {
                    store.endSimulation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
        }
    }

    private var transportStatusTitle: String {
        switch store.transportState {
        case .connected:
            if let lastRealtimeSignalAt = store.lastRealtimeSignalAt,
               Date().timeIntervalSince(lastRealtimeSignalAt) > 12
            {
                return "Checking"
            }
            return "Live"
        case .catchingUp:
            return "Catching Up"
        case .reconnecting:
            return "Recovering"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Offline"
        }
    }

    private var transportStatusSymbol: String {
        switch store.transportState {
        case .connected:
            return "dot.radiowaves.left.and.right"
        case .catchingUp:
            return "arrow.triangle.2.circlepath"
        case .reconnecting:
            return "bolt.horizontal.circle"
        case .connecting:
            return "hourglass"
        case .disconnected:
            return "wifi.slash"
        }
    }

    private var transportStatusTint: Color {
        switch store.transportState {
        case .connected:
            if let lastRealtimeSignalAt = store.lastRealtimeSignalAt,
               Date().timeIntervalSince(lastRealtimeSignalAt) > 12
            {
                return .orange
            }
            return .green
        case .catchingUp:
            return .blue
        case .reconnecting, .connecting:
            return .orange
        case .disconnected:
            return .secondary
        }
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
                                    .frame(minWidth: 20, minHeight: 20)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .font(tabFont(for: layoutMode).weight(store.activeConversationID == conversation.id ? .semibold : .regular))
                        .padding(.horizontal, layoutMode == .padWorkspace ? 14 : 10)
                        .padding(.vertical, layoutMode == .padWorkspace ? 8 : 6)
                        .background(
                            store.activeConversationID == conversation.id
                                ? Color.blue.opacity(0.18)
                                : Color.secondary.opacity(0.08),
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalInset(for: layoutMode))
            .padding(.vertical, 2)
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
                                ChatBubble(item: item, layoutMode: layoutMode, mediaLoader: mediaLoader) {
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
                .scrollDismissesKeyboard(.interactively)
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
                    axis: .vertical,
                )
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .disabled(store.activeConversationLocked)
                .focused($composerIsFocused)
                .onChange(of: store.draftText) { _, _ in
                    store.notifyTypingChanged()
                }

                if isKeyboardPresented {
                    Button {
                        dismissKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Hide keyboard")
                }

                Button {
                    store.sendDraft()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.activeConversationLocked ||
                        store.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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
        compact: Bool,
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
                .fill(chatSystemBackgroundColor()),
        )
    }

    private func toolsPanel(layoutMode: ChatRunLayoutMode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layoutMode == .padWorkspace ? 14 : 12) {
                toolsHeader(layoutMode: layoutMode)
                toolSection(.activity, layoutMode: layoutMode) {
                    ChatActivityRows(items: store.activityItems)
                }
                toolSection(.patientHistory, layoutMode: layoutMode) {
                    PatientHistoryRows(rows: toolsStore.toolData("patient_history"))
                }
                toolSection(.patientResults, layoutMode: layoutMode) {
                    ToolDataRows(rows: toolsStore.toolData("patient_results"))
                }
                if simulationHasEnded {
                    toolSection(.simulationFeedback, layoutMode: layoutMode) {
                        SimulationFeedbackRows(rows: toolsStore.toolData("simulation_feedback"))
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

            submitOrdersPanel(compact: layoutMode != .padWorkspace)

            if let error = toolsStore.presentableError {
                InlineAppErrorView(error: error)
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

    private func submitOrdersPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !toolsStore.stagedOrders.isEmpty {
                Text("\(toolsStore.stagedOrders.count) order\(toolsStore.stagedOrders.count == 1 ? "" : "s") ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            VStack(alignment: .leading, spacing: 0) {
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
            .padding(compact ? 10 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(compact ? Color.secondary.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolSection(
        _ section: ChatToolsSection,
        layoutMode: ChatRunLayoutMode,
        @ViewBuilder content: () -> some View,
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
            ChatToolsSection.allCases.filter { $0.defaultExpanded(for: layoutMode) },
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

    private func dismissKeyboard() {
        composerIsFocused = false
        #if os(iOS)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func tabFont(for layoutMode: ChatRunLayoutMode) -> Font {
        switch layoutMode {
        case .compactMessenger:
            .caption
        case .widePhoneMessenger:
            .subheadline
        case .padWorkspace:
            .subheadline
        }
    }

    private func horizontalInset(for layoutMode: ChatRunLayoutMode) -> CGFloat {
        switch layoutMode {
        case .compactMessenger:
            10
        case .widePhoneMessenger:
            14
        case .padWorkspace:
            0
        }
    }

    private func messageColumnWidth(for layoutMode: ChatRunLayoutMode) -> CGFloat {
        switch layoutMode {
        case .compactMessenger:
            560
        case .widePhoneMessenger:
            620
        case .padWorkspace:
            760
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

private struct ChatHideRunNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
        #else
            content
        #endif
    }
}

private struct ChatBubble: View {
    let item: ChatMessageItem
    let layoutMode: ChatRunLayoutMode
    let mediaLoader: ChatMediaLoading
    let retryAction: () -> Void

    var body: some View {
        HStack {
            if item.isFromSelf {
                Spacer(minLength: layoutMode == .padWorkspace ? 120 : 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                if !item.isFromSelf {
                    Text(item.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                bubbleContent
                if let errorText = item.errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(layoutMode == .padWorkspace ? 11 : 10)
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
            320
        case .widePhoneMessenger:
            420
        case .padWorkspace:
            620
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if !item.content.isEmpty, prefersInlineFooter {
            inlineFooterText
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if !item.content.isEmpty {
                    Text(item.content)
                        .font(.body)
                }
                if !item.mediaList.isEmpty {
                    mediaStrip
                }
                footerRow
            }
        }
    }

    private var inlineFooterText: Text {
        var segments: [Text] = [
            Text(item.content).font(.body),
            Text("  "),
            Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary),
        ]

        if !item.isFromSelf, !item.isRead {
            segments.append(Text("  "))
            segments.append(
                Text("Unread")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange),
            )
        }

        if item.isFromSelf {
            segments.append(Text("  "))
            segments.append(
                Text(item.deliveryStatus.rawValue.capitalized)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor(item.deliveryStatus)),
            )
        }

        return segments.dropFirst().reduce(segments[0]) { partialResult, segment in
            partialResult + segment
        }
    }

    private var metadataText: String {
        var parts = [item.timestamp.formatted(date: .omitted, time: .shortened)]
        if !item.isFromSelf, !item.isRead {
            parts.append("Unread")
        }
        if item.isFromSelf {
            parts.append(item.deliveryStatus.rawValue.capitalized)
        }
        return parts.joined(separator: " ")
    }

    private var prefersInlineFooter: Bool {
        ChatBubbleFooterLayout.prefersInline(
            in: .init(
                content: item.content,
                metadataText: metadataText,
                bubbleWidth: bubbleWidth(for: layoutMode),
                hasMedia: item.mediaList.isEmpty == false,
                hasError: item.errorText?.isEmpty == false,
                hasRetryAction: item.isFromSelf && item.deliveryStatus == .failed && item.retryable,
            ),
        )
    }

    private var mediaStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(item.mediaList.prefix(3)) { media in
                VStack(alignment: .leading, spacing: 4) {
                    ChatMediaThumbnail(media: media, loader: mediaLoader)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)

                    if !media.description.isEmpty {
                        Text(media.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var footerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !item.isFromSelf, !item.isRead {
                    Text("Unread")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
                if item.isFromSelf {
                    Text(item.deliveryStatus.rawValue.capitalized)
                        .font(.caption2.bold())
                        .foregroundStyle(statusColor(item.deliveryStatus))
                }
            }
            if item.isFromSelf, item.deliveryStatus == .failed, item.retryable {
                Button("Retry", action: retryAction)
                    .font(.caption2.bold())
            }
        }
    }

    private func statusColor(_ status: DeliveryStatus) -> Color {
        switch status {
        case .sending:
            .secondary
        case .sent:
            .blue
        case .delivered:
            .green
        case .failed:
            .red
        }
    }
}

private struct ChatActivityRows: View {
    let items: [ChatActivityItem]

    var body: some View {
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity will show recovery and simulation updates here.")
                    .font(.footnote.weight(.semibold))
                Text("Manual refreshes, reconnect recovery, feedback generation changes, and patient result updates appear in this feed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items.prefix(12)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(item.eventType)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
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

private struct ChatMediaThumbnail: View {
    let media: ChatMessageMedia
    let loader: ChatMediaLoading

    @StateObject private var model: ChatMediaThumbnailModel

    init(media: ChatMessageMedia, loader: ChatMediaLoading) {
        self.media = media
        self.loader = loader
        _model = StateObject(wrappedValue: ChatMediaThumbnailModel(media: media, loader: loader))
    }

    var body: some View {
        Group {
            switch model.state {
            case let .loaded(image):
                image
                    .resizable()
                    .scaledToFill()
            case .idle, .loading:
                loadingView
            case .failed:
                mediaFailureView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            model.loadIfNeeded()
        }
    }

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay(ProgressView().controlSize(.small))
    }

    private var mediaFailureView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Unable to load media")
                        .font(.caption.weight(.semibold))
                    if !media.mimeType.isEmpty {
                        Text(media.mimeType)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
    }
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
                                Text(ChatToolValueFormatter.friendlyLabel(for: key))
                                    .font(.caption.bold())
                                Spacer()
                                Text(ChatToolValueFormatter.render(row[key] ?? .null))
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
                            Text(ChatToolValueFormatter.render(summary))
                                .font(.subheadline.weight(.semibold))
                        }
                        if let value = row["value"] {
                            Text(ChatToolValueFormatter.render(value))
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
                        Text(prettyKey(row["key"].map(ChatToolValueFormatter.render) ?? "Unknown"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row["value"].map(ChatToolValueFormatter.render) ?? "-")
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
        ChatToolValueFormatter.friendlyLabel(for: key)
    }
}

private struct SimulationFeedbackRows: View {
    let rows: [[String: JSONValue]]

    var body: some View {
        if rows.isEmpty {
            Text("No feedback yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let fields = ChatFeedbackPresentation.fields(from: row)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(field.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                                    .font(.footnote)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}
