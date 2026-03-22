import Foundation
import Networking
import OSLog
import Persistence
import Realtime
import SharedModels

private let logger = Logger(subsystem: "com.jackfruit.medsim", category: "TrainerSessionStore")

@MainActor
public final class RunSessionStore: ObservableObject {
    @Published public private(set) var state: RunSessionState = .init()

    private let service: TrainerLabServiceProtocol
    private let realtimeClient: RealtimeClientProtocol
    private let commandQueue: CommandQueueStoreProtocol

    @Published public private(set) var interventionDictionary: [InterventionGroup] = InterventionDictionary.bundled
    @Published public private(set) var injuryDictionary: InjuryDictionary?
    @Published public private(set) var runtimeState: TrainerRuntimeStateOut?
    @Published public private(set) var scenarioBrief: ScenarioBriefOut?
    @Published public private(set) var controlPlaneDebug: ControlPlaneDebugOut?
    @Published public private(set) var debriefAnnotations: [AnnotationOut] = []
    @Published public private(set) var assessmentFindings: [RuntimeAssessmentFindingState] = []
    @Published public private(set) var diagnosticResults: [RuntimeDiagnosticResultState] = []
    @Published public private(set) var resources: [RuntimeResourceState] = []
    @Published public private(set) var disposition: RuntimeDispositionState?
    @Published public private(set) var patientStatus: RuntimePatientStatus = .init()

    private var eventTask: Task<Void, Never>?
    private var transportTask: Task<Void, Never>?
    private var vitalsTask: Task<Void, Never>?
    private var stopwatchTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?
    private var runtimeRefreshTask: Task<Void, Never>?
    private var lastAppliedLifecycleRevision: Int?
    private var pendingRuntimeRefresh = false

    private let runtimeRefreshDebounceNanoseconds: UInt64 = 150_000_000
    private let maxTimelineEvents = 400

    private struct SessionLifecycleSnapshot {
        let status: TrainerSessionStatus
        let scenarioSpec: [String: JSONValue]?
        let modifiedAt: Date
        let runStartedAt: Date?
        let runPausedAt: Date?
        let runCompletedAt: Date?
        let terminalReasonCode: String?
        let terminalReasonText: String?
        let retryable: Bool?
    }

    private struct EventHandlingOutcome {
        let shouldRehydrateSeededSession: Bool
        let shouldRefreshRuntimeState: Bool
        let canonicalEventType: String
    }

    public init(
        service: TrainerLabServiceProtocol,
        realtimeClient: RealtimeClientProtocol,
        commandQueue: CommandQueueStoreProtocol,
    ) {
        self.service = service
        self.realtimeClient = realtimeClient
        self.commandQueue = commandQueue
    }

    public func bind(session: TrainerSessionDTO) {
        state = RunSessionReducer.reduce(state: state, action: .sessionLoaded(session))
        syncStopwatchState()
        syncTransportPresentation(for: state.transportState)
    }

    public func startConsole() {
        guard let session = state.session else {
            return
        }

        eventTask?.cancel()
        transportTask?.cancel()
        vitalsTask?.cancel()
        stopwatchTask?.cancel()
        bootstrapTask?.cancel()
        runtimeRefreshTask?.cancel()
        pendingRuntimeRefresh = false

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in realtimeClient.events {
                let outcome = await handleIncomingEvent(event)
                if outcome.shouldRehydrateSeededSession {
                    await refreshSession()
                    await loadAnnotations()
                }
                if outcome.shouldRefreshRuntimeState {
                    await scheduleRuntimeRefresh(reason: "event \(outcome.canonicalEventType)")
                }
            }
        }

        transportTask = Task { [weak self] in
            guard let self else { return }
            for await transport in realtimeClient.transportStates {
                await MainActor.run {
                    logger.info(
                        "Realtime transport for simulation \(self.state.session?.simulationID ?? -1, privacy: .public) -> \(self.transportDescription(transport), privacy: .public)",
                    )
                    self.state = RunSessionReducer.reduce(state: self.state, action: .transportChanged(transport))
                    self.syncTransportPresentation(for: transport)
                }
            }
        }

        vitalsTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await MainActor.run {
                    self.updateVitalMeasurements()
                    self.pruneInactiveInjuries(now: Date())
                }
            }
        }

        stopwatchTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.tickStopwatch()
                }
            }
        }

        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            await bootstrapConsole(for: session)
        }

        loadInterventionDictionary()
    }

    public func stopConsole() {
        eventTask?.cancel()
        transportTask?.cancel()
        vitalsTask?.cancel()
        stopwatchTask?.cancel()
        bootstrapTask?.cancel()
        runtimeRefreshTask?.cancel()
        pendingRuntimeRefresh = false
        realtimeClient.disconnect()
    }

    /// Fire-and-forget: loads the intervention and injury dictionaries from the API.
    public func loadInterventionDictionary() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let groups = try await service.interventionDictionary()
                if !groups.isEmpty {
                    await MainActor.run { self.interventionDictionary = groups }
                }
            } catch {
                // Silently ignore; bundled fallback remains active
            }
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let dict = try await service.injuryDictionary()
                await MainActor.run { self.injuryDictionary = dict }
            } catch {
                // Non-critical; UI falls back to hardcoded labels
            }
        }
    }

    /// Loads the runtime state (scenario brief, AI plan, rationale notes) on demand.
    @discardableResult
    public func loadRuntimeState(reason: String = "manual") async -> TrainerRuntimeStateOut? {
        guard let simulationID = state.session?.simulationID else { return nil }
        logger.info("Fetching runtime state for simulation \(simulationID, privacy: .public) (\(reason, privacy: .public))")
        do {
            let rs = try await service.getRuntimeState(simulationID: simulationID)
            logger.info(
                "Fetched runtime state for simulation \(simulationID, privacy: .public): revision=\(rs.stateRevision, privacy: .public) status=\(rs.status, privacy: .public)",
            )
            applyRuntimeState(rs, source: reason)
            return rs
        } catch {
            logger.error(
                "Runtime state fetch failed for simulation \(simulationID, privacy: .public) (\(reason, privacy: .public)): \(error.localizedDescription, privacy: .public)",
            )
            return nil
        }
    }

    public func loadControlPlaneDebug() async {
        guard let simulationID = state.session?.simulationID else { return }
        do {
            controlPlaneDebug = try await service.getControlPlaneDebug(simulationID: simulationID)
        } catch {
            // Optional debug surface; ignore fetch failures.
        }
    }

    public func loadAnnotations() async {
        guard let simulationID = state.session?.simulationID else { return }
        do {
            debriefAnnotations = try await service.listAnnotations(simulationID: simulationID)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            // Optional UI; keep current list if fetch fails.
        }
    }

    private func bootstrapConsole(for session: TrainerSessionDTO) async {
        logger.info("Bootstrapping TrainerLab console for simulation \(session.simulationID, privacy: .public)")

        _ = await loadRuntimeState(reason: "bootstrap")

        let historicalEvents = await loadHistoricalEvents(simulationID: session.simulationID)
        applyHistoricalEvents(historicalEvents)

        let eventCursor = state.eventCursor
        logger.info(
            "Connecting realtime stream for simulation \(session.simulationID, privacy: .public) from cursor \(eventCursor ?? "nil", privacy: .public)",
        )
        await realtimeClient.connect(simulationID: session.simulationID, cursor: eventCursor)
        await loadAnnotations()
        await replayPendingCommands()
        await refreshPendingCount()
    }

    private func loadHistoricalEvents(simulationID: Int) async -> [EventEnvelope] {
        var events: [EventEnvelope] = []
        var cursor: String?
        var seenCursors = Set<String>()

        while !Task.isCancelled {
            do {
                let page = try await service.listEvents(simulationID: simulationID, cursor: cursor, limit: maxTimelineEvents)
                logger.info(
                    "Fetched \(page.items.count, privacy: .public) historical events for simulation \(simulationID, privacy: .public) cursor \(cursor ?? "nil", privacy: .public)",
                )
                events.append(contentsOf: page.items)

                guard page.hasMore else { break }
                guard let nextCursor = page.nextCursor else {
                    logger.warning(
                        "Historical events for simulation \(simulationID, privacy: .public) reported more pages without a next cursor",
                    )
                    break
                }
                guard seenCursors.insert(nextCursor).inserted else {
                    logger.warning(
                        "Stopping historical events pagination for simulation \(simulationID, privacy: .public) because cursor \(nextCursor, privacy: .public) repeated",
                    )
                    break
                }
                cursor = nextCursor
            } catch {
                logger.error(
                    "Historical events fetch failed for simulation \(simulationID, privacy: .public): \(error.localizedDescription, privacy: .public)",
                )
                break
            }
        }

        return normalizedEvents(events)
    }

    private func applyHistoricalEvents(_ events: [EventEnvelope]) {
        guard !events.isEmpty else {
            let simulationID = state.session?.simulationID ?? -1
            logger.info("No historical events found for simulation \(simulationID, privacy: .public)")
            normalizeStoredTimelineEvents()
            return
        }

        state.timeline = normalizedEvents(state.timeline + events)
        state.eventCursor = state.timeline.last?.eventID
        rebuildClinicalTimelineEntries(from: state.timeline)
        let timelineCount = state.timeline.count
        let simulationID = state.session?.simulationID ?? -1
        logger.info(
            "Applied \(timelineCount, privacy: .public) historical events for simulation \(simulationID, privacy: .public)",
        )
    }

    private func normalizeStoredTimelineEvents() {
        state.timeline = normalizedEvents(state.timeline)
        state.eventCursor = state.timeline.last?.eventID
    }

    private func normalizedEvents(_ events: [EventEnvelope]) -> [EventEnvelope] {
        let sorted = events.map { $0.canonicalized() }.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.eventID < rhs.eventID
        }

        var seenEventIDs = Set<String>()
        var deduped: [EventEnvelope] = []
        deduped.reserveCapacity(sorted.count)
        for event in sorted where seenEventIDs.insert(event.eventID).inserted {
            deduped.append(event)
        }

        if deduped.count > maxTimelineEvents {
            deduped.removeFirst(deduped.count - maxTimelineEvents)
        }
        return deduped
    }

    private func rebuildClinicalTimelineEntries(from events: [EventEnvelope]) {
        state.clinicalTimelineEntries = []
        for event in events {
            captureClinicalTimelineEntry(from: event)
        }
        state.clinicalTimelineEntries.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.dedupeKey > rhs.dedupeKey
        }
    }

    private func handleIncomingEvent(_ event: EventEnvelope) async -> EventHandlingOutcome {
        let canonicalEvent = event.canonicalized()
        let eventType = canonicalEvent.eventType
        logger.info(
            "Received runtime event \(eventType, privacy: .public) id=\(event.eventID, privacy: .public)",
        )

        let previousStatus = state.session?.status
        state = RunSessionReducer.reduce(state: state, action: .eventReceived(canonicalEvent))
        normalizeStoredTimelineEvents()

        let shouldRehydrateSeededSession = handleSimulationStatusUpdated(canonicalEvent, previousStatus: previousStatus)
        applyLiveEventProjection(from: canonicalEvent)
        captureClinicalTimelineEntry(from: canonicalEvent, previousStatus: previousStatus)
        syncStopwatchState(previousStatus: previousStatus)

        return EventHandlingOutcome(
            shouldRehydrateSeededSession: shouldRehydrateSeededSession,
            shouldRefreshRuntimeState: shouldRefreshRuntimeProjection(for: canonicalEvent),
            canonicalEventType: eventType,
        )
    }

    public func refreshSession() async {
        guard let simulationID = state.session?.simulationID else {
            return
        }

        do {
            let latest = try await service.getSession(simulationID: simulationID)
            let previousStatus = state.session?.status
            state = RunSessionReducer.reduce(state: state, action: .sessionLoaded(latest))
            state = RunSessionReducer.reduce(state: state, action: .clearConflict)
            syncStopwatchState(previousStatus: previousStatus)
        } catch {
            state.conflictBanner = error.localizedDescription
        }
    }

    public func retryInitialSimulation() {
        guard let simulationID = state.session?.simulationID else { return }

        Task {
            do {
                let updated = try await service.retryInitialSimulation(simulationID: simulationID)
                let previousStatus = state.session?.status
                state = RunSessionReducer.reduce(state: state, action: .sessionLoaded(updated))
                state = RunSessionReducer.reduce(state: state, action: .clearConflict)
                syncStopwatchState(previousStatus: previousStatus)
                _ = await loadRuntimeState(reason: "retry initial simulation")
            } catch {
                state.conflictBanner = error.localizedDescription
            }
        }
    }

    public func start() {
        guard canRunCommands else { return }
        Task { await sendRunCommand(.start) }
    }

    public func pause() {
        guard canRunCommands else { return }
        Task { await sendRunCommand(.pause) }
    }

    public func resume() {
        guard canRunCommands else { return }
        Task { await sendRunCommand(.resume) }
    }

    public func stop() {
        guard canRunCommands else { return }
        Task { await sendRunCommand(.stop) }
    }

    public func adjustAVPU(_ avpu: AVPUState) {
        guard canMutateCommands else { return }

        Task {
            guard let session = state.session else { return }
            let request = SimulationAdjustRequest(
                target: "avpu",
                direction: "set",
                magnitude: nil,
                injuryEventID: nil,
                injuryRegion: nil,
                avpuState: avpu.rawValue,
                interventionCode: nil,
                note: "Set AVPU to \(avpu.rawValue)",
                metadata: [:],
            )
            let path = "/api/v1/trainerlab/simulations/\(session.simulationID)/adjust/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: body,
                simulationID: session.simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                let ack = try await self.service.adjustSimulation(simulationID: session.simulationID, request: request, idempotencyKey: envelope.idempotencyKey)
                return TrainerCommandAck(commandID: ack.commandID, status: ack.status)
            }
        }
    }

    public func addIntervention(
        interventionType: String,
        siteCode: String,
        targetProblemID: Int? = nil,
        status: InterventionStatus = .applied,
        effectiveness: InterventionEffectiveness = .unknown,
        notes: String = "",
        details: [String: JSONValue]? = nil,
        tourniquetApplicationMode: TourniquetApplicationMode? = nil,
        supersedesEventID: Int? = nil,
    ) {
        guard canInterventionCommands else { return }
        guard let targetProblemID else {
            state.conflictBanner = "Select a target problem before recording an intervention."
            return
        }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let request = InterventionEventRequest(
                interventionType: interventionType,
                siteCode: siteCode,
                targetProblemID: targetProblemID,
                status: status,
                effectiveness: effectiveness,
                notes: notes,
                details: details,
                tourniquetApplicationMode: tourniquetApplicationMode,
                supersedesEventID: supersedesEventID,
            )
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/events/interventions/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: body,
                simulationID: simulationID,
            )

            // Optimistic local timeline entry
            let typeLabel = interventionDictionary
                .first(where: { $0.interventionType == interventionType })?.label
                ?? interventionType.replacingOccurrences(of: "_", with: " ").capitalized
            let siteLabel = interventionDictionary
                .first(where: { $0.interventionType == interventionType })?
                .sites.first(where: { $0.code == siteCode })?.label
                ?? siteCode.replacingOccurrences(of: "_", with: " ").capitalized
            let message = siteCode.isEmpty ? typeLabel : "\(typeLabel) — \(siteLabel)"
            addClinicalTimelineEntry(
                dedupeKey: "opt:\(envelope.idempotencyKey)",
                kind: .intervention,
                title: "Intervention",
                message: message,
                createdAt: Date(),
                metadata: [
                    "intervention_type": interventionType,
                    "site_code": siteCode,
                    "effectiveness": effectiveness.rawValue,
                    "intervention_status": status.rawValue,
                ],
            )

            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.injectInterventionEvent(simulationID: simulationID, request: request, idempotencyKey: envelope.idempotencyKey)
            }
        }
    }

    public func addInjuryEvent(category: String, location: String, kind: String, description: String) {
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let request = InjuryEventRequest(
                injuryLocation: location,
                injuryKind: kind,
                injuryDescription: description,
                description: description,
            )
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/events/injuries/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: body,
                simulationID: simulationID,
            )

            addOptimisticInjury(
                id: "pending:\(envelope.idempotencyKey)",
                locationCode: location,
                category: category,
                kind: kind,
                summary: description,
            )

            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.injectInjuryEvent(simulationID: simulationID, request: request, idempotencyKey: envelope.idempotencyKey)
            }
        }
    }

    public func addIllnessEvent(name: String, description: String, marchCategory _: String, severity _: String) {
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let request = IllnessEventRequest(name: name, description: description)
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/events/illnesses/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: body,
                simulationID: simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.injectIllnessEvent(simulationID: simulationID, request: request, idempotencyKey: envelope.idempotencyKey)
            }
        }
    }

    public func addVitalEvent(type: String, min: Int, max: Int) {
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let seeded = randomVitalNumbers(
                key: type,
                minValue: min,
                maxValue: max,
                minDiastolic: nil,
                maxDiastolic: nil,
            )
            upsertVital(
                VitalStatusSnapshot(
                    key: type,
                    minValue: min,
                    maxValue: max,
                    minValueDiastolic: nil,
                    maxValueDiastolic: nil,
                    lockValue: false,
                    currentValue: seeded.primary,
                    currentDiastolicValue: seeded.secondary,
                ),
            )

            let request = VitalEventRequest(
                vitalType: type,
                minValue: min,
                maxValue: max,
                lockValue: false,
                minValueDiastolic: nil,
                maxValueDiastolic: nil,
                supersedesEventID: nil,
            )
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/events/vitals/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: body,
                simulationID: simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.injectVitalEvent(simulationID: simulationID, request: request, idempotencyKey: envelope.idempotencyKey)
            }
        }
    }

    public func createDebriefAnnotation(
        observationText: String,
        learningObjective: AnnotationLearningObjective,
        outcome: AnnotationOutcome,
        linkedEventID: Int? = nil,
    ) {
        let trimmed = observationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let request = AnnotationCreateRequest(
                observationText: String(trimmed.prefix(2000)),
                learningObjective: learningObjective,
                outcome: outcome,
                linkedEventID: linkedEventID,
                elapsedSecondsAt: state.stopwatchElapsedSeconds,
            )

            do {
                let created = try await service.createAnnotation(
                    simulationID: simulationID,
                    request: request,
                    idempotencyKey: UUID().uuidString,
                )
                debriefAnnotations.insert(created, at: 0)
            } catch {
                state.conflictBanner = error.localizedDescription
            }
        }
    }

    public func steerPrompt(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let key = UUID().uuidString
            let request = SteerPromptRequest(prompt: String(trimmed.prefix(2000)))
            _ = try? await service.steerPrompt(
                simulationID: simulationID,
                request: request,
                idempotencyKey: key,
            )
        }
    }

    public func triggerRunTick() {
        guard canMutateCommands else { return }
        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/"
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: Data(),
                simulationID: simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.triggerRunTick(
                    simulationID: simulationID,
                    idempotencyKey: envelope.idempotencyKey,
                )
            }
            await loadRuntimeState()
            await loadControlPlaneDebug()
        }
    }

    public func triggerVitalsTick() {
        guard canMutateCommands else { return }
        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/vitals/"
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.post.rawValue,
                body: Data(),
                simulationID: simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.triggerVitalsTick(
                    simulationID: simulationID,
                    idempotencyKey: envelope.idempotencyKey,
                )
            }
            await loadRuntimeState()
            await loadControlPlaneDebug()
        }
    }

    public func purgeAbandonedCommands() async {
        do {
            _ = try await commandQueue.purgeAbandoned()
            await refreshPendingCount()
        } catch {
            state.conflictBanner = error.localizedDescription
        }
    }

    public func replayPendingCommands() async {
        do {
            guard let simulationID = state.session?.simulationID else { return }
            let batch = try await commandQueue.nextRetryBatch(limit: 25, now: Date(), simulationID: simulationID)
            for envelope in batch {
                if let envelopeSimulationID = envelope.resolvedSimulationID, envelopeSimulationID != simulationID {
                    continue
                }
                let data = envelope.bodyBase64.flatMap { Data(base64Encoded: $0) }
                do {
                    try await service.replayPending(
                        endpoint: envelope.endpoint,
                        method: envelope.method,
                        body: data,
                        idempotencyKey: envelope.idempotencyKey,
                    )
                    try await commandQueue.markAcked(idempotencyKey: envelope.idempotencyKey)
                } catch {
                    if isTerminalReplayFailure(error) {
                        try await commandQueue.markTerminalFailure(
                            idempotencyKey: envelope.idempotencyKey,
                            error: error.localizedDescription,
                        )
                    } else {
                        let nextRetryAt = Date().addingTimeInterval(nextBackoffSeconds(for: envelope.retryCount))
                        try await commandQueue.markFailed(
                            idempotencyKey: envelope.idempotencyKey,
                            error: error.localizedDescription,
                            nextRetryAt: nextRetryAt,
                        )
                    }
                }
            }
            await refreshPendingCount()
        } catch {
            state.conflictBanner = error.localizedDescription
        }
    }

    private var canMutateCommands: Bool {
        state.commandChannelAvailable && state.session?.status != .seeding
    }

    private var canRunCommands: Bool {
        canMutateCommands
    }

    private var canInterventionCommands: Bool {
        canMutateCommands
    }

    private func sendRunCommand(_ command: RunCommand) async {
        guard let session = state.session else {
            return
        }

        let path = "/api/v1/trainerlab/simulations/\(session.simulationID)/run/\(command.rawValue)/"
        let body = Data()
        let envelope = CommandEnvelopeBuilder.make(
            endpoint: path,
            method: HTTPMethod.post.rawValue,
            body: body,
            simulationID: session.simulationID,
        )

        await executeQueuedSessionCommand(envelope: envelope) {
            try await self.service.runCommand(simulationID: session.simulationID, command: command, idempotencyKey: envelope.idempotencyKey)
        }
    }

    private func executeQueuedSessionCommand(
        envelope: PendingCommandEnvelope,
        run: @escaping @Sendable () async throws -> TrainerSessionDTO,
    ) async {
        do {
            try await commandQueue.enqueue(envelope)
            await refreshPendingCount()

            let session = try await run()
            let previousStatus = state.session?.status
            state = RunSessionReducer.reduce(state: state, action: .sessionLoaded(session))
            syncStopwatchState(previousStatus: previousStatus)
            try await commandQueue.markAcked(idempotencyKey: envelope.idempotencyKey)
            await refreshPendingCount()
        } catch {
            await handleCommandError(error, envelope: envelope)
        }
    }

    private func executeQueuedAckCommand(
        envelope: PendingCommandEnvelope,
        run: @escaping @Sendable () async throws -> some Sendable,
    ) async {
        do {
            try await commandQueue.enqueue(envelope)
            await refreshPendingCount()
            _ = try await run()
            try await commandQueue.markAcked(idempotencyKey: envelope.idempotencyKey)
            await refreshPendingCount()
        } catch {
            await handleCommandError(error, envelope: envelope)
        }
    }

    private func handleCommandError(_ error: Error, envelope: PendingCommandEnvelope) async {
        if let apiError = error as? APIClientError, case let .http(statusCode, detail, _) = apiError, statusCode == 409 {
            state = RunSessionReducer.reduce(state: state, action: .conflict(detail))
            await refreshSession()
        }

        let nextRetryAt = Date().addingTimeInterval(nextBackoffSeconds(for: envelope.retryCount))
        do {
            try await commandQueue.markFailed(
                idempotencyKey: envelope.idempotencyKey,
                error: error.localizedDescription,
                nextRetryAt: nextRetryAt,
            )
            await refreshPendingCount()
        } catch {
            state.conflictBanner = error.localizedDescription
        }
    }

    private func refreshPendingCount() async {
        do {
            guard let simulationID = state.session?.simulationID else {
                state = RunSessionReducer.reduce(state: state, action: .pendingCommandCountChanged(0))
                return
            }

            let count = try await commandQueue.pendingCount(simulationID: simulationID)
            state = RunSessionReducer.reduce(state: state, action: .pendingCommandCountChanged(count))
        } catch {
            state.conflictBanner = error.localizedDescription
        }
    }

    private func scheduleRuntimeRefresh(reason: String) async {
        pendingRuntimeRefresh = true
        logger.debug("Queued authoritative runtime refresh (\(reason, privacy: .public))")
        guard runtimeRefreshTask == nil else { return }
        runtimeRefreshTask = Task { [weak self] in
            guard let self else { return }
            await flushScheduledRuntimeRefreshes()
        }
    }

    private func flushScheduledRuntimeRefreshes() async {
        defer { runtimeRefreshTask = nil }

        while pendingRuntimeRefresh, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: runtimeRefreshDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            pendingRuntimeRefresh = false
            _ = await loadRuntimeState(reason: "coalesced live refresh")
        }
    }

    private func transportDescription(_ transport: RealtimeTransportState) -> String {
        switch transport {
        case .connectedSSE:
            "connected_sse"
        case .polling:
            "polling"
        case let .reconnecting(attempt):
            "reconnecting_\(attempt)"
        case .connecting:
            "connecting"
        case .disconnected:
            "disconnected"
        }
    }

    private func syncTransportPresentation(for transport: RealtimeTransportState) {
        switch transport {
        case .connectedSSE:
            state.commandChannelAvailable = true
            state.transportBanner = TransportBanner(style: .healthy, message: "SSE Healthy", visible: true)
        case .polling:
            state.commandChannelAvailable = false
            state.transportBanner = TransportBanner(style: .warning, message: "Polling Fallback", visible: true)
        case .reconnecting:
            state.commandChannelAvailable = false
            state.transportBanner = TransportBanner(style: .warning, message: "Reconnecting", visible: true)
        case .connecting:
            state.commandChannelAvailable = false
            state.transportBanner = TransportBanner(style: .warning, message: "Reconnecting", visible: true)
        case .disconnected:
            state.commandChannelAvailable = false
            state.transportBanner = TransportBanner(style: .error, message: "Disconnected", visible: true)
        }
    }

    private func handleSimulationStatusUpdated(
        _ event: EventEnvelope,
        previousStatus: TrainerSessionStatus?,
    ) -> Bool {
        guard event.eventType == SimulationEventType.simulationStatusUpdated else { return false }
        guard let session = state.session else { return false }

        do {
            let payload = try event.decodePayload(SimulationStatusUpdatedPayload.self)

            if let payloadSimulationID = payload.simulationID, payloadSimulationID != session.simulationID {
                logger.warning(
                    "Ignoring simulation.status.updated for simulation \(payloadSimulationID, privacy: .public); bound simulation is \(session.simulationID, privacy: .public)",
                )
                return false
            }

            guard let nextStatus = payload.trainerSessionStatus(previousStatus: previousStatus) else {
                logger.debug(
                    "Ignoring simulation.status.updated with unmapped status \(payload.status ?? "nil", privacy: .public) for simulation \(session.simulationID, privacy: .public)",
                )
                return false
            }

            if let revision = payload.stateRevision {
                guard shouldApplyLifecycleRevision(revision, expectedStatus: nextStatus) else {
                    logger.debug(
                        "Ignoring stale simulation.status.updated revision \(revision, privacy: .public) for simulation \(session.simulationID, privacy: .public)",
                    )
                    return false
                }
            } else if nextStatus != .completed, nextStatus != .failed, event.createdAt < session.modifiedAt {
                logger.debug(
                    "Ignoring stale simulation.status.updated for simulation \(session.simulationID, privacy: .public)",
                )
                return false
            }

            let semantic = payload.lifecycleSemantic(previousStatus: previousStatus)
            let updatedSession = sessionWithLifecycleUpdate(
                from: session,
                snapshot: SessionLifecycleSnapshot(
                    status: nextStatus,
                    scenarioSpec: payload.scenarioSpec,
                    modifiedAt: max(session.modifiedAt, event.createdAt),
                    runStartedAt: resolvedRunStartedAt(
                        for: nextStatus,
                        semantic: semantic,
                        session: session,
                        event: event,
                    ),
                    runPausedAt: resolvedRunPausedAt(
                        for: nextStatus,
                        session: session,
                        event: event,
                    ),
                    runCompletedAt: resolvedRunCompletedAt(
                        for: nextStatus,
                        payload: payload,
                        session: session,
                        event: event,
                    ),
                    terminalReasonCode: nextStatus == .failed || nextStatus == .completed ? payload.effectiveReasonCode : nil,
                    terminalReasonText: nextStatus == .failed || nextStatus == .completed ? payload.effectiveReasonText : nil,
                    retryable: nextStatus == .failed || nextStatus == .completed ? payload.retryable : nil,
                ),
            )

            state = RunSessionReducer.reduce(state: state, action: .sessionLoaded(updatedSession))
            state = RunSessionReducer.reduce(state: state, action: .clearConflict)
            if let revision = payload.stateRevision {
                noteLifecycleRevision(revision)
            }

            if nextStatus == .failed {
                logger.warning(
                    "Simulation \(updatedSession.simulationID, privacy: .public) transitioned to failed state: \(updatedSession.terminalReasonText ?? "Simulation failed.", privacy: .public)",
                )
            }

            return semantic == .seeded
        } catch {
            logger.error(
                "Failed to decode simulation.status.updated payload for simulation \(session.simulationID, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            return false
        }
    }

    private func shouldApplyLifecycleRevision(_ revision: Int, expectedStatus: TrainerSessionStatus) -> Bool {
        guard let lastAppliedLifecycleRevision else { return true }
        if revision > lastAppliedLifecycleRevision {
            return true
        }
        guard revision == lastAppliedLifecycleRevision else {
            return false
        }

        switch expectedStatus {
        case .seeded:
            return true
        case .seeding:
            return state.session?.status == .seeding
        default:
            return state.session?.status == expectedStatus
        }
    }

    private func noteLifecycleRevision(_ revision: Int) {
        if let lastAppliedLifecycleRevision {
            self.lastAppliedLifecycleRevision = max(lastAppliedLifecycleRevision, revision)
        } else {
            lastAppliedLifecycleRevision = revision
        }
    }

    private func sessionWithLifecycleUpdate(
        from session: TrainerSessionDTO,
        snapshot: SessionLifecycleSnapshot,
    ) -> TrainerSessionDTO {
        TrainerSessionDTO(
            simulationID: session.simulationID,
            status: snapshot.status,
            scenarioSpec: snapshot.scenarioSpec ?? session.scenarioSpec,
            runtimeState: session.runtimeState,
            initialDirectives: session.initialDirectives,
            tickIntervalSeconds: session.tickIntervalSeconds,
            runStartedAt: snapshot.runStartedAt,
            runPausedAt: snapshot.runPausedAt,
            runCompletedAt: snapshot.runCompletedAt,
            lastAITickAt: session.lastAITickAt,
            createdAt: session.createdAt,
            modifiedAt: snapshot.modifiedAt,
            terminalReasonCode: snapshot.terminalReasonCode,
            terminalReasonText: snapshot.terminalReasonText,
            retryable: snapshot.retryable,
        )
    }

    private func resolvedRunStartedAt(
        for nextStatus: TrainerSessionStatus,
        semantic: SimulationLifecycleSemantic,
        session: TrainerSessionDTO,
        event: EventEnvelope,
    ) -> Date? {
        switch nextStatus {
        case .seeding, .seeded:
            return nil
        case .running:
            if semantic == .resumed {
                return session.runStartedAt
            }
            return session.runStartedAt ?? event.createdAt
        case .paused, .completed, .failed:
            return session.runStartedAt
        }
    }

    private func resolvedRunPausedAt(
        for nextStatus: TrainerSessionStatus,
        session: TrainerSessionDTO,
        event: EventEnvelope,
    ) -> Date? {
        switch nextStatus {
        case .paused:
            return event.createdAt
        case .completed, .failed:
            return session.runPausedAt
        case .seeding, .seeded, .running:
            return nil
        }
    }

    private func resolvedRunCompletedAt(
        for nextStatus: TrainerSessionStatus,
        payload: SimulationStatusUpdatedPayload,
        session: TrainerSessionDTO,
        event: EventEnvelope,
    ) -> Date? {
        switch nextStatus {
        case .completed, .failed:
            return payload.terminalAt ?? event.createdAt
        case .seeding, .seeded, .running, .paused:
            return nil
        }
    }

    private func captureClinicalTimelineEntry(
        from event: EventEnvelope,
        previousStatus: TrainerSessionStatus? = nil,
    ) {
        let eventType = event.eventType

        if eventType == SimulationEventType.simulationStatusUpdated,
           let payload = try? event.decodePayload(SimulationStatusUpdatedPayload.self)
        {
            let display = SimulationEventRegistry.lifecycleDisplay(for: payload, previousStatus: previousStatus)
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .lifecycle,
                title: display.title,
                message: display.message,
                createdAt: event.createdAt,
            )
            return
        }

        if eventType == SimulationEventType.simulationSnapshotUpdated {
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Runtime State Updated",
                message: eventPrimaryLabel(from: event.payload) ?? "Authoritative runtime state refreshed.",
                createdAt: event.createdAt,
            )
            return
        }

        if eventType == SimulationEventType.simulationPlanUpdated {
            let summary = jsonString(event.payload["summary"])
                ?? jsonString(event.payload["title"])
                ?? jsonString(event.payload["trigger"])
                ?? "Instructor intent updated."
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "AI Instructor",
                message: summary,
                createdAt: event.createdAt,
            )
            return
        }

        if isCauseEvent(eventType: eventType) {
            let kindTitle = eventType == SimulationEventType.patientInjuryCreated || eventType == SimulationEventType.patientInjuryUpdated
                ? "Injury"
                : "Illness"
            let summary = eventPrimaryLabel(from: event.payload) ?? kindTitle
            let location = jsonString(event.payload["anatomical_location"])
                ?? jsonString(event.payload["injury_location"])
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .cause,
                title: kindTitle,
                message: location.map { "\($0): \(summary)" } ?? summary,
                createdAt: event.createdAt,
            )
            return
        }

        if isProblemEvent(eventType: eventType) {
            let label = eventPrimaryLabel(from: event.payload) ?? "Problem"
            let status = jsonString(event.payload["status"]) ?? "active"
            let severity = jsonString(event.payload["severity"])
            let message = "\(label) — \(status.replacingOccurrences(of: "_", with: " ").capitalized)"
                + (severity.map { " (\($0.capitalized))" } ?? "")
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .problem,
                title: "Problem",
                message: message,
                createdAt: event.createdAt,
                metadata: ["status": status],
            )
            return
        }

        if isRecommendedInterventionEvent(eventType: eventType) {
            let label = eventPrimaryLabel(from: event.payload) ?? "Recommendation"
            let targetProblemID = jsonInt(event.payload["target_problem_id"]).map(String.init)
            var metadata: [String: String] = [:]
            if let targetProblemID { metadata["target_problem_id"] = targetProblemID }
            if let priority = jsonString(event.payload["priority"]) { metadata["priority"] = priority }
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .recommendation,
                title: "Recommendation",
                message: label,
                createdAt: event.createdAt,
                metadata: metadata,
            )
            return
        }

        if isVitalEvent(eventType: eventType) {
            let vitalType = jsonString(event.payload["vital_type"])
                ?? inferVitalType(from: jsonString(event.payload["domain_event_type"]))
                ?? "vitals"
            let minValue = jsonInt(event.payload["min_value"])
            let maxValue = jsonInt(event.payload["max_value"])
            let message: String = if let minValue, let maxValue {
                "\(SimulationEventRegistry.humanizedLabel(vitalType)) range \(minValue)-\(maxValue)"
            } else {
                eventPrimaryLabel(from: event.payload) ?? "\(SimulationEventRegistry.humanizedLabel(vitalType)) updated"
            }
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .vitals,
                title: "Vital Update",
                message: message,
                createdAt: event.createdAt,
            )
            return
        }

        if isPulseEvent(eventType: eventType, payload: event.payload) {
            let location = jsonString(event.payload["location"]).map(SimulationEventRegistry.humanizedLabel) ?? "Pulse"
            let present = jsonBool(event.payload["present"])
            let quality = jsonString(event.payload["quality"]) ?? jsonString(event.payload["description"])
            let presenceText = present.map { $0 ? "present" : "absent" } ?? "updated"
            let message = quality.map { "\(location) \(presenceText) (\($0))" } ?? "\(location) \(presenceText)"
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .vitals,
                title: "Pulse Update",
                message: message,
                createdAt: event.createdAt,
            )
            return
        }

        if isNoteEvent(eventType: eventType, payload: event.payload) {
            let content = jsonString(event.payload["content"])
                ?? jsonString(event.payload["note"])
                ?? "Note recorded"
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Trainer Note",
                message: content,
                createdAt: event.createdAt,
            )
            return
        }

        if isInterventionEvent(eventType: eventType, payload: event.payload) {
            let interventionType = jsonString(event.payload["intervention_type"]) ?? ""
            let siteCode = jsonString(event.payload["site_code"]) ?? ""
            let effectiveness = jsonString(event.payload["effectiveness"]) ?? "unknown"
            let status = jsonString(event.payload["status"]) ?? "applied"
            let supersedesID = jsonInt(event.payload["supersedes_event_id"]).map(String.init)
                ?? jsonString(event.payload["superseded_by"])

            // Build human label from dictionary if available
            let typeLabel = interventionDictionary.first(where: { $0.interventionType == interventionType })?.label
                ?? interventionType.replacingOccurrences(of: "_", with: " ").capitalized
            let siteLabel = interventionDictionary
                .first(where: { $0.interventionType == interventionType })?
                .sites.first(where: { $0.code == siteCode })?.label
                ?? siteCode.replacingOccurrences(of: "_", with: " ").capitalized

            let message = siteCode.isEmpty ? typeLabel : "\(typeLabel) — \(siteLabel)"

            var meta: [String: String] = [
                "intervention_type": interventionType,
                "site_code": siteCode,
                "effectiveness": effectiveness,
                "intervention_status": status,
            ]
            if let supersedesID { meta["superseded_by"] = supersedesID }

            // Mark any superseded entry
            if let supersedesID {
                markTimelineEntrySuperseded(id: supersedesID, byEventID: event.eventID)
            }

            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .intervention,
                title: "Intervention",
                message: message,
                createdAt: event.createdAt,
                metadata: meta,
            )
            return
        }

        if isScenarioBriefEvent(eventType: eventType, payload: event.payload) {
            let content = jsonString(event.payload["read_aloud_brief"])
                ?? jsonString(event.payload["title"])
                ?? jsonString(event.payload["location_overview"])
                ?? "Scenario brief updated."
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Scenario Brief",
                message: content,
                createdAt: event.createdAt,
            )
            return
        }

        if eventType == SimulationEventType.simulationAdjustmentUpdated,
           jsonString(event.payload["target"]) == "avpu"
        {
            let stateText = jsonString(event.payload["avpu_state"]) ?? "unknown"
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .loc,
                title: "LOC Change",
                message: "AVPU set to \(stateText.capitalized)",
                createdAt: event.createdAt,
            )
            return
        }

        if isAssessmentFindingEvent(eventType: eventType) {
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Assessment Finding",
                message: eventPrimaryLabel(from: event.payload) ?? "Assessment finding updated.",
                createdAt: event.createdAt,
            )
            return
        }

        if isDiagnosticResultEvent(eventType: eventType) {
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Diagnostic Result",
                message: eventPrimaryLabel(from: event.payload) ?? "Diagnostic result updated.",
                createdAt: event.createdAt,
            )
            return
        }

        if isResourceEvent(eventType: eventType) {
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Resource Update",
                message: eventPrimaryLabel(from: event.payload) ?? "Resource state updated.",
                createdAt: event.createdAt,
            )
            return
        }

        if isDispositionEvent(eventType: eventType) {
            addClinicalTimelineEntry(
                dedupeKey: "event:\(event.eventID)",
                kind: .note,
                title: "Disposition",
                message: eventPrimaryLabel(from: event.payload) ?? "Disposition updated.",
                createdAt: event.createdAt,
            )
            return
        }

        addClinicalTimelineEntry(
            dedupeKey: "event:\(event.eventID)",
            kind: .note,
            title: SimulationEventRegistry.displayTitle(for: eventType, payload: event.payload, previousStatus: previousStatus),
            message: eventPrimaryLabel(from: event.payload) ?? "Runtime event received.",
            createdAt: event.createdAt,
        )
    }

    private func addClinicalTimelineEntry(
        dedupeKey: String,
        kind: ClinicalTimelineKind,
        title: String,
        message: String,
        createdAt: Date,
        metadata: [String: String] = [:],
    ) {
        if state.clinicalTimelineEntries.contains(where: { $0.dedupeKey == dedupeKey }) {
            return
        }

        state.clinicalTimelineEntries.append(
            ClinicalTimelineEntry(
                dedupeKey: dedupeKey,
                kind: kind,
                title: title,
                message: message,
                createdAt: createdAt,
                metadata: metadata,
            ),
        )

        state.clinicalTimelineEntries.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.dedupeKey > rhs.dedupeKey
        }

        if state.clinicalTimelineEntries.count > maxTimelineEvents {
            state.clinicalTimelineEntries.removeLast(state.clinicalTimelineEntries.count - maxTimelineEvents)
        }
    }

    /// Tags the timeline entry identified by `eventID` as superseded, so the view
    /// can render it with a muted/struck-through style.
    private func markTimelineEntrySuperseded(id supersededID: String, byEventID: String) {
        let dedupeKey = "event:\(supersededID)"
        guard let idx = state.clinicalTimelineEntries.firstIndex(where: { $0.dedupeKey == dedupeKey }) else { return }
        let entry = state.clinicalTimelineEntries[idx]
        var meta = entry.metadata
        meta["superseded_by"] = byEventID
        state.clinicalTimelineEntries[idx] = ClinicalTimelineEntry(
            id: entry.id,
            dedupeKey: entry.dedupeKey,
            kind: entry.kind,
            title: entry.title,
            message: entry.message,
            createdAt: entry.createdAt,
            metadata: meta,
        )
    }

    private func applyLiveEventProjection(from event: EventEnvelope) {
        switch event.eventType {
        case SimulationEventType.simulationBriefCreated, SimulationEventType.simulationBriefUpdated:
            if let decoded = try? event.payload.decodedPayload(as: ScenarioBriefOut.self) {
                scenarioBrief = decoded
            }

        case SimulationEventType.patientAssessmentFindingCreated, SimulationEventType.patientAssessmentFindingUpdated:
            upsertAssessmentFinding(from: event)

        case SimulationEventType.patientAssessmentFindingRemoved:
            removeAssessmentFinding(from: event)

        case SimulationEventType.patientDiagnosticResultCreated, SimulationEventType.patientDiagnosticResultUpdated:
            upsertDiagnosticResult(from: event)

        case SimulationEventType.patientResourceUpdated:
            upsertResourceState(from: event)

        case SimulationEventType.patientDispositionUpdated:
            if let decoded = try? event.payload.decodedPayload(as: RuntimeDispositionState.self) {
                disposition = decoded
            }

        default:
            break
        }

        captureVitalRange(from: event)
        captureInjuryAnnotation(from: event)
        captureProblemAnnotation(from: event)
        captureRecommendedIntervention(from: event)
        captureInterventionAnnotation(from: event)
        capturePulseAnnotation(from: event)
    }

    private func upsertAssessmentFinding(from event: EventEnvelope) {
        guard let finding = try? event.payload.decodedPayload(as: RuntimeAssessmentFindingState.self) else { return }
        guard let findingID = finding.findingID else {
            assessmentFindings.append(finding)
            return
        }

        if let idx = assessmentFindings.firstIndex(where: { $0.findingID == findingID }) {
            assessmentFindings[idx] = finding
        } else {
            assessmentFindings.append(finding)
        }
    }

    private func removeAssessmentFinding(from event: EventEnvelope) {
        guard let findingID = jsonInt(event.payload["finding_id"]) else { return }
        assessmentFindings.removeAll { $0.findingID == findingID }
    }

    private func upsertDiagnosticResult(from event: EventEnvelope) {
        guard let result = try? event.payload.decodedPayload(as: RuntimeDiagnosticResultState.self) else { return }
        guard let resultID = result.resultID else {
            diagnosticResults.append(result)
            return
        }

        if let idx = diagnosticResults.firstIndex(where: { $0.resultID == resultID }) {
            diagnosticResults[idx] = result
        } else {
            diagnosticResults.append(result)
        }
    }

    private func upsertResourceState(from event: EventEnvelope) {
        guard let resource = try? event.payload.decodedPayload(as: RuntimeResourceState.self) else { return }
        guard let resourceID = resource.resourceID else {
            resources.append(resource)
            return
        }

        if let idx = resources.firstIndex(where: { $0.resourceID == resourceID }) {
            resources[idx] = resource
        } else {
            resources.append(resource)
        }
    }

    private func captureVitalRange(from event: EventEnvelope) {
        let eventType = event.eventType
        let resolvedVitalType = jsonString(event.payload["vital_type"])
            ?? inferVitalType(from: jsonString(event.payload["domain_event_type"]))

        guard
            eventType == SimulationEventType.patientVitalCreated
                || eventType == SimulationEventType.patientVitalUpdated
                || resolvedVitalType != nil
        else {
            return
        }

        guard
            let vitalType = resolvedVitalType,
            let minValue = jsonInt(event.payload["min_value"]),
            let maxValue = jsonInt(event.payload["max_value"])
        else {
            return
        }

        let lockValue = jsonBool(event.payload["lock_value"]) ?? false
        let minDiastolic = jsonInt(event.payload["min_value_diastolic"])
        let maxDiastolic = jsonInt(event.payload["max_value_diastolic"])
        let sampled = randomVitalNumbers(
            key: vitalType,
            minValue: minValue,
            maxValue: maxValue,
            minDiastolic: minDiastolic,
            maxDiastolic: maxDiastolic,
        )

        let existing = state.vitals.first(where: { $0.key == vitalType })
        let snapshot = VitalStatusSnapshot(
            key: vitalType,
            minValue: minValue,
            maxValue: maxValue,
            minValueDiastolic: minDiastolic,
            maxValueDiastolic: maxDiastolic,
            lockValue: lockValue,
            previousValue: existing?.currentValue,
            previousDiastolicValue: existing?.currentDiastolicValue,
            currentValue: sampled.primary,
            currentDiastolicValue: sampled.secondary,
            trend: .flat,
            changeToken: existing?.changeToken ?? 0,
            lastUpdatedAt: event.createdAt,
        )
        upsertVital(snapshot)
    }

    private func upsertVital(_ snapshot: VitalStatusSnapshot) {
        if let existingIndex = state.vitals.firstIndex(where: { $0.key == snapshot.key }) {
            state.vitals[existingIndex] = snapshot
        } else {
            state.vitals.append(snapshot)
        }
    }

    private func updateVitalMeasurements() {
        guard state.session?.status == .running else {
            return
        }
        guard !state.vitals.isEmpty else {
            return
        }

        for index in state.vitals.indices {
            if state.vitals[index].lockValue {
                continue
            }

            let oldPrimary = state.vitals[index].currentValue
            let oldSecondary = state.vitals[index].currentDiastolicValue
            let sampled = randomVitalNumbers(
                key: state.vitals[index].key,
                minValue: state.vitals[index].minValue,
                maxValue: state.vitals[index].maxValue,
                minDiastolic: state.vitals[index].minValueDiastolic,
                maxDiastolic: state.vitals[index].maxValueDiastolic,
                currentPrimary: oldPrimary,
                currentSecondary: oldSecondary,
            )

            state.vitals[index].previousValue = oldPrimary
            state.vitals[index].previousDiastolicValue = oldSecondary
            state.vitals[index].currentValue = sampled.primary
            state.vitals[index].currentDiastolicValue = sampled.secondary
            state.vitals[index].trend = trendDirection(
                oldPrimary: oldPrimary,
                oldSecondary: oldSecondary,
                newPrimary: sampled.primary,
                newSecondary: sampled.secondary,
            )
            if sampled.primary != oldPrimary || sampled.secondary != oldSecondary {
                state.vitals[index].changeToken += 1
            }
            state.vitals[index].lastUpdatedAt = Date()
        }
    }

    private func randomVitalNumbers(
        key: String,
        minValue: Int,
        maxValue: Int,
        minDiastolic: Int?,
        maxDiastolic: Int?,
        currentPrimary: Int? = nil,
        currentSecondary: Int? = nil,
    ) -> (primary: Int, secondary: Int?) {
        let primary = constrainedRandom(
            low: min(minValue, maxValue),
            high: max(minValue, maxValue),
            current: currentPrimary,
        )

        if key == "blood_pressure", let minDiastolic, let maxDiastolic {
            let secondary = constrainedRandom(
                low: min(minDiastolic, maxDiastolic),
                high: max(minDiastolic, maxDiastolic),
                current: currentSecondary,
            )
            return (primary, secondary)
        }

        return (primary, nil)
    }

    /// Samples a value within [low, high] that drifts at most ~8% of the range per tick
    /// from `current`. When `current` is nil (first sample) the full range is used.
    private func constrainedRandom(low: Int, high: Int, current: Int?) -> Int {
        guard low < high else { return low }
        guard let current else {
            return Int.random(in: low ... high)
        }
        let maxStep = max(2, Int(Double(high - low) * 0.08))
        let stepLow = max(low, current - maxStep)
        let stepHigh = min(high, current + maxStep)
        if stepLow > stepHigh {
            return Int.random(in: low ... high)
        }
        return Int.random(in: stepLow ... stepHigh)
    }

    private func trendDirection(
        oldPrimary: Int,
        oldSecondary: Int?,
        newPrimary: Int,
        newSecondary: Int?,
    ) -> VitalTrendDirection {
        if newPrimary > oldPrimary {
            return .up
        }
        if newPrimary < oldPrimary {
            return .down
        }
        if let oldSecondary, let newSecondary {
            if newSecondary > oldSecondary { return .up }
            if newSecondary < oldSecondary { return .down }
        }
        return .flat
    }

    private func syncStopwatchState(previousStatus: TrainerSessionStatus? = nil) {
        let status = state.session?.status
        let isTerminal = status == .completed || status == .failed

        // Show terminal card when session first reaches a terminal state
        if isTerminal, state.terminalCard == nil {
            state.terminalCard = TerminalCard(
                status: status!,
                reasonText: state.session?.terminalReasonText,
                completedAt: state.session?.runCompletedAt,
            )
        } else if !isTerminal {
            state.terminalCard = nil
        }

        let shouldRun = status == .running

        if shouldRun {
            if !state.stopwatchIsRunning {
                state.stopwatchIsRunning = true
                state.stopwatchRunningSince = Date()
                if state.stopwatchElapsedSeconds == 0,
                   let startedAt = state.session?.runStartedAt
                {
                    state.stopwatchElapsedSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
                }
            }
            return
        }

        if state.stopwatchIsRunning, let started = state.stopwatchRunningSince {
            state.stopwatchElapsedSeconds += max(0, Int(Date().timeIntervalSince(started)))
        }
        state.stopwatchIsRunning = false
        state.stopwatchRunningSince = nil

        if status == .seeded, previousStatus == nil {
            state.stopwatchElapsedSeconds = 0
        }

        if status == .completed,
           let startedAt = state.session?.runStartedAt,
           let endedAt = state.session?.runCompletedAt
        {
            state.stopwatchElapsedSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        }
    }

    private func tickStopwatch() {
        guard state.stopwatchIsRunning, let runningSince = state.stopwatchRunningSince else {
            return
        }
        let now = Date()
        let delta = max(0, Int(now.timeIntervalSince(runningSince)))
        if delta > 0 {
            state.stopwatchElapsedSeconds += delta
            state.stopwatchRunningSince = now
        }
    }

    private func captureInjuryAnnotation(from event: EventEnvelope) {
        let eventType = event.eventType
        guard isCauseEvent(eventType: eventType) else {
            return
        }

        guard
            let locationCode = resolvedAnatomicLocationCode(
                primary: jsonString(event.payload["anatomical_location"]) ?? jsonString(event.payload["injury_location"]),
                fallback: nil,
            ),
            let zone = injuryZone(for: locationCode)
        else {
            return
        }

        let causeID = jsonInt(event.payload["cause_id"])
        let domainEventID = jsonInt(event.payload["domain_event_id"]).map(String.init)
            ?? causeID.map(String.init)
            ?? event.eventID
        let category = jsonString(event.payload["march_category"])
        let kind = jsonString(event.payload["kind"])
            ?? jsonString(event.payload["injury_kind"])
            ?? (eventType == SimulationEventType.patientInjuryCreated || eventType == SimulationEventType.patientInjuryUpdated ? "injury" : "illness")
        let title = eventPrimaryLabel(from: event.payload) ?? "Cause"
        let summary = jsonString(event.payload["description"])
            ?? jsonString(event.payload["injury_description"])
            ?? title
        let supersedes = jsonInt(event.payload["supersedes_event_id"]).map(String.init)

        if let supersedes {
            markInjuryInactive(id: supersedes)
        }

        if eventType == SimulationEventType.patientInjuryCreated || eventType == SimulationEventType.patientInjuryUpdated {
            reconcilePendingInjury(locationCode: locationCode, kind: kind, summary: summary)
        }

        let annotation = InjuryAnnotation(
            id: domainEventID,
            causeID: causeID,
            locationCode: locationCode,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            category: category,
            kind: kind,
            code: jsonString(event.payload["code"]),
            title: title,
            displayName: jsonString(event.payload["display_name"]),
            summary: summary,
            severity: jsonString(event.payload["severity"]),
            status: .active,
            source: jsonString(event.payload["source"]) ?? jsonString(event.payload["origin"]),
            supersedesEventID: supersedes,
            hiddenAfter: nil,
            updatedAt: event.createdAt,
        )

        upsertInjury(annotation)
    }

    private func addOptimisticInjury(
        id: String,
        locationCode: String,
        category: String,
        kind: String,
        summary: String,
    ) {
        guard let zone = injuryZone(for: locationCode) else {
            return
        }

        let annotation = InjuryAnnotation(
            id: id,
            locationCode: locationCode,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            category: category,
            kind: kind,
            summary: summary,
            status: .pending,
            updatedAt: Date(),
        )
        upsertInjury(annotation)
    }

    private func reconcilePendingInjury(locationCode: String, kind: String, summary: String) {
        if let idx = state.injuryAnnotations.firstIndex(where: {
            $0.status == .pending && $0.locationCode == locationCode && $0.kind == kind && $0.summary == summary
        }) {
            state.injuryAnnotations.remove(at: idx)
        }
    }

    private func markInjuryInactive(id: String) {
        guard let idx = state.injuryAnnotations.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.injuryAnnotations[idx].status = .inactive
        state.injuryAnnotations[idx].hiddenAfter = Date().addingTimeInterval(15)
        state.injuryAnnotations[idx].updatedAt = Date()
    }

    private func pruneInactiveInjuries(now: Date) {
        state.injuryAnnotations.removeAll { annotation in
            guard annotation.status == .inactive else { return false }
            guard let hiddenAfter = annotation.hiddenAfter else { return false }
            return now >= hiddenAfter
        }
    }

    private func upsertInjury(_ annotation: InjuryAnnotation) {
        if let idx = state.injuryAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            state.injuryAnnotations[idx] = annotation
        } else {
            state.injuryAnnotations.append(annotation)
        }
    }

    // MARK: - Intervention Annotations

    private func captureInterventionAnnotation(from event: EventEnvelope) {
        guard isInterventionEvent(eventType: event.eventType, payload: event.payload) else { return }

        let interventionType = jsonString(event.payload["intervention_type"])
            ?? jsonString(event.payload["normalized_kind"])
            ?? ""
        let siteCode = (jsonString(event.payload["site_code"]) ?? "").uppercased()
        let effectiveness = jsonString(event.payload["effectiveness"]) ?? "unknown"
        let status = jsonString(event.payload["status"]) ?? "applied"

        guard let zone = interventionZone(for: siteCode) else { return }

        let interventionID = jsonInt(event.payload["intervention_id"])
        let domainEventID = jsonInt(event.payload["domain_event_id"]).map(String.init)
            ?? interventionID.map(String.init)
            ?? event.eventID

        let annotation = InterventionAnnotation(
            id: domainEventID,
            interventionID: interventionID,
            interventionType: interventionType,
            title: eventPrimaryLabel(from: event.payload) ?? interventionType,
            siteCode: siteCode,
            siteLabel: jsonString(event.payload["site_label"]),
            targetProblemID: jsonInt(event.payload["target_problem_id"]),
            targetCauseID: jsonInt(event.payload["target_cause_id"]),
            targetCauseKind: jsonString(event.payload["target_cause_kind"]),
            validationStatus: jsonString(event.payload["validation_status"]),
            adjudicationReason: jsonString(event.payload["adjudication_reason"]),
            warnings: jsonStringArray(event.payload["warnings"]),
            contraindications: jsonStringArray(event.payload["contraindications"]),
            side: zone.side,
            x: zone.x,
            y: zone.y,
            effectiveness: effectiveness,
            status: status,
            updatedAt: event.createdAt,
        )

        if let idx = state.interventionAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            state.interventionAnnotations[idx] = annotation
        } else {
            state.interventionAnnotations.append(annotation)
        }
    }

    private func interventionZone(for siteCode: String) -> (side: InjuryZoneSide, x: Double, y: Double)? {
        // Reuse injury zone map — intervention site codes often map to the same body regions
        if let zone = InjuryZoneMap.table[siteCode] {
            return zone
        }
        // Map common intervention site codes to body positions
        return InterventionSiteMap.table[siteCode]
    }

    // MARK: - Problem Annotations

    private func captureProblemAnnotation(from event: EventEnvelope) {
        let eventType = event.eventType
        guard isProblemEvent(eventType: eventType) else { return }

        let problemID = jsonInt(event.payload["problem_id"])
        let domainEventID = problemID.map(String.init)
            ?? jsonInt(event.payload["domain_event_id"]).map(String.init)
            ?? event.eventID
        let label = eventPrimaryLabel(from: event.payload) ?? "Problem"
        let status = ProblemLifecycleState(rawValue: jsonString(event.payload["status"]) ?? "active") ?? .active
        let severity = jsonString(event.payload["severity"])
        let locationCode = resolvedAnatomicLocationCode(
            primary: jsonString(event.payload["anatomical_location"]) ?? jsonString(event.payload["injury_location"]),
            fallback: jsonInt(event.payload["cause_id"]).flatMap { causeID in
                state.causeAnnotations.first(where: { $0.causeID == causeID })?.locationCode
            },
        )

        let zone = locationCode.flatMap { injuryZone(for: $0) }
        let isAnatomic = zone != nil

        let annotation = ProblemAnnotation(
            id: domainEventID,
            problemID: problemID,
            title: label,
            displayName: jsonString(event.payload["display_name"]),
            description: jsonString(event.payload["description"]),
            isAnatomic: isAnatomic,
            locationCode: locationCode,
            side: zone?.side,
            x: zone?.x,
            y: zone?.y,
            status: status,
            previousStatus: ProblemLifecycleState(rawValue: jsonString(event.payload["previous_status"]) ?? ""),
            severity: severity,
            causeID: jsonInt(event.payload["cause_id"]),
            causeKind: jsonString(event.payload["cause_kind"]),
            recommendedInterventionIDs: jsonIntArray(event.payload["recommended_interventions"]),
            adjudicationReason: jsonString(event.payload["adjudication_reason"]),
            updatedAt: event.createdAt,
        )

        if let idx = state.problemAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            state.problemAnnotations[idx] = annotation
        } else {
            state.problemAnnotations.append(annotation)
        }
    }

    private func captureRecommendedIntervention(from event: EventEnvelope) {
        let eventType = event.eventType
        guard isRecommendedInterventionEvent(eventType: eventType) else { return }

        guard let recommendationID = jsonInt(event.payload["recommendation_id"]) else { return }
        if eventType == SimulationEventType.patientRecommendedInterventionRemoved {
            state.recommendedInterventions.removeAll { $0.recommendationID == recommendationID }
            return
        }

        let item = RecommendedInterventionItem(
            recommendationID: recommendationID,
            title: eventPrimaryLabel(from: event.payload) ?? "Recommendation",
            code: jsonString(event.payload["code"]),
            kind: jsonString(event.payload["kind"]),
            targetProblemID: jsonInt(event.payload["target_problem_id"]),
            targetCauseID: jsonInt(event.payload["target_cause_id"]),
            targetCauseKind: jsonString(event.payload["target_cause_kind"]),
            recommendationSource: jsonString(event.payload["recommendation_source"]),
            validationStatus: jsonString(event.payload["validation_status"]),
            normalizedKind: jsonString(event.payload["normalized_kind"]),
            normalizedCode: jsonString(event.payload["normalized_code"]),
            rationale: jsonString(event.payload["rationale"]),
            priority: jsonString(event.payload["priority"]),
            siteCode: jsonString(event.payload["site_code"]),
            siteLabel: jsonString(event.payload["site_label"]),
            warnings: jsonStringArray(event.payload["warnings"]),
            contraindications: jsonStringArray(event.payload["contraindications"]),
        )

        if let idx = state.recommendedInterventions.firstIndex(where: { $0.recommendationID == recommendationID }) {
            state.recommendedInterventions[idx] = item
        } else {
            state.recommendedInterventions.append(item)
        }
    }

    // MARK: - Pulse Annotations

    private func capturePulseAnnotation(from event: EventEnvelope) {
        if let annotation = makePulseAnnotation(from: event) {
            if let idx = state.pulseAnnotations.firstIndex(where: { $0.location == annotation.location }) {
                state.pulseAnnotations[idx] = annotation
            } else {
                state.pulseAnnotations.append(annotation)
            }
            return
        }

        let domainEventType = jsonString(event.payload["domain_event_type"])?.lowercased()
        let eventKind = jsonString(event.payload["event_kind"])?.lowercased()
        guard domainEventType == "pulseassessment" || eventKind == "pulse_assessment" else { return }

        guard
            let location = jsonString(event.payload["location"]),
            let zone = PulseZoneMap.table[location]
        else { return }

        let domainEventID = jsonInt(event.payload["domain_event_id"]).map(String.init) ?? event.eventID
        let present = jsonBool(event.payload["present"]) ?? true
        let quality = jsonString(event.payload["description"]) ?? "strong"

        let annotation = PulseAnnotation(
            id: domainEventID,
            location: location,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            present: present,
            quality: quality,
            colorNormal: jsonBool(event.payload["color_normal"]) ?? true,
            colorDescription: jsonString(event.payload["color_description"]) ?? "pink",
            conditionNormal: jsonBool(event.payload["condition_normal"]) ?? true,
            conditionDescription: jsonString(event.payload["condition_description"]) ?? "dry",
            temperatureNormal: jsonBool(event.payload["temperature_normal"]) ?? true,
            temperatureDescription: jsonString(event.payload["temperature_description"]) ?? "warm",
            updatedAt: event.createdAt,
        )

        if let idx = state.pulseAnnotations.firstIndex(where: { $0.location == location }) {
            state.pulseAnnotations[idx] = annotation
        } else {
            state.pulseAnnotations.append(annotation)
        }
    }

    // MARK: - Problem Status

    public func updateProblemStatus(problemID: Int, status: ProblemLifecycleState) {
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let request = ProblemStatusUpdateRequest(
                isTreated: status == .active ? false : true,
                isResolved: status == .resolved,
            )
            let path = "/api/v1/trainerlab/simulations/\(simulationID)/problems/\(problemID)/"
            let body = try? JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: path,
                method: HTTPMethod.patch.rawValue,
                body: body,
                simulationID: simulationID,
            )
            await executeQueuedAckCommand(envelope: envelope) {
                try await self.service.updateProblemStatus(
                    simulationID: simulationID,
                    problemID: problemID,
                    request: request,
                    idempotencyKey: envelope.idempotencyKey,
                )
            }
        }
    }

    // MARK: - Scenario Brief Update

    public func updateScenarioBrief(_ request: ScenarioBriefUpdateRequest) {
        guard canMutateCommands else { return }

        Task {
            guard let simulationID = state.session?.simulationID else { return }
            let key = UUID().uuidString
            do {
                let updated = try await service.updateScenarioBrief(
                    simulationID: simulationID,
                    request: request,
                    idempotencyKey: key,
                )
                scenarioBrief = updated
            } catch {
                state.conflictBanner = error.localizedDescription
            }
        }
    }

    // MARK: - Reconcile annotations from runtime state on reconnect

    private func reconcileAnnotationsFromSnapshot() async {
        guard let runtimeState else { return }
        applyRuntimeState(runtimeState, source: "reconcile")
    }

    private func hydrateHiddenClinicalState(from snapshot: TrainerRuntimeSnapshot) {
        assessmentFindings = snapshot.assessmentFindings
        diagnosticResults = snapshot.diagnosticResults
        resources = snapshot.resources
        disposition = snapshot.disposition
        patientStatus = snapshot.patientStatus
    }

    private func makeVitalSnapshot(
        from vitalState: RuntimeVitalState,
        existing: VitalStatusSnapshot?,
    ) -> VitalStatusSnapshot? {
        guard
            let vitalType = vitalState.vitalType?.trimmingCharacters(in: .whitespacesAndNewlines),
            !vitalType.isEmpty,
            let minValue = vitalState.minValue,
            let maxValue = vitalState.maxValue
        else {
            logger.debug("Skipping invalid runtime vital payload during authoritative apply")
            return nil
        }

        let sampled = randomVitalNumbers(
            key: vitalType,
            minValue: minValue,
            maxValue: maxValue,
            minDiastolic: vitalState.minValueDiastolic,
            maxDiastolic: vitalState.maxValueDiastolic,
            currentPrimary: existing?.currentValue,
            currentSecondary: existing?.currentDiastolicValue,
        )

        let trend = vitalState.trend.flatMap(VitalTrendDirection.init(rawValue:))
            ?? existing?.trend
            ?? .flat

        return VitalStatusSnapshot(
            key: vitalType,
            minValue: minValue,
            maxValue: maxValue,
            minValueDiastolic: vitalState.minValueDiastolic,
            maxValueDiastolic: vitalState.maxValueDiastolic,
            lockValue: vitalState.lockValue ?? false,
            previousValue: existing?.currentValue,
            previousDiastolicValue: existing?.currentDiastolicValue,
            currentValue: sampled.primary,
            currentDiastolicValue: sampled.secondary,
            trend: trend,
            changeToken: existing?.changeToken ?? 0,
            lastUpdatedAt: parseISODate(vitalState.timestamp) ?? Date(),
        )
    }

    private func applyRuntimeState(_ runtimeState: TrainerRuntimeStateOut, source: String) {
        let snapshot = runtimeState.currentSnapshot
        logger.info(
            "Applying runtime state for simulation \(runtimeState.simulationID, privacy: .public) from \(source, privacy: .public): revision=\(runtimeState.stateRevision, privacy: .public)",
        )

        self.runtimeState = runtimeState
        scenarioBrief = runtimeState.scenarioBrief
        hydrateHiddenClinicalState(from: snapshot)
        noteLifecycleRevision(runtimeState.stateRevision)

        let causesByID = Dictionary(uniqueKeysWithValues: snapshot.causes.compactMap { cause in
            cause.causeID.map { ($0, cause) }
        })
        let problemsByID = Dictionary(uniqueKeysWithValues: snapshot.problems.compactMap { problem in
            problem.problemID.map { ($0, problem) }
        })
        let existingVitalsByKey = Dictionary(uniqueKeysWithValues: state.vitals.map { ($0.key, $0) })

        state.causeAnnotations = snapshot.causes.compactMap { cause in
            makeCauseAnnotation(from: cause, fallbackProblem: cause.causeID.flatMap { causeID in
                snapshot.problems.first(where: { $0.causeID == causeID })
            })
        }
        state.problemAnnotations = snapshot.problems.map { problem in
            makeProblemAnnotation(from: problem, causesByID: causesByID)
        }
        state.recommendedInterventions = snapshot.recommendedInterventions.map { recommendation in
            makeRecommendedInterventionItem(from: recommendation, problemsByID: problemsByID)
        }
        state.interventionAnnotations = snapshot.interventions.compactMap(makeInterventionAnnotation)
        state.pulseAnnotations = snapshot.pulses.compactMap(makePulseAnnotation)
        state.vitals = snapshot.vitals.compactMap { vitalState in
            let existing = vitalState.vitalType.flatMap { existingVitalsByKey[$0] }
            return makeVitalSnapshot(from: vitalState, existing: existing)
        }
    }

    private func makeCauseAnnotation(
        from cause: RuntimeCauseState,
        fallbackProblem: RuntimeProblemState?,
    ) -> CauseAnnotation? {
        let locationCode = resolvedAnatomicLocationCode(
            primary: cause.anatomicalLocation ?? cause.injuryLocation,
            fallback: fallbackProblem?.anatomicalLocation,
        )
        guard let locationCode, let zone = injuryZone(for: locationCode) else {
            return nil
        }

        let id = cause.domainEventID.map(String.init)
            ?? cause.causeID.map(String.init)
            ?? cause.primaryLabel

        return CauseAnnotation(
            id: id,
            causeID: cause.causeID,
            locationCode: locationCode,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            category: cause.marchCategory,
            kind: cause.kind ?? cause.code ?? "cause",
            code: cause.code,
            title: cause.primaryLabel,
            displayName: cause.displayName,
            summary: cause.description ?? cause.primaryLabel,
            severity: cause.severity,
            status: .active,
            source: cause.source,
            supersedesEventID: nil,
            hiddenAfter: nil,
            updatedAt: parseISODate(cause.timestamp) ?? Date(),
        )
    }

    private func makeProblemAnnotation(
        from problem: RuntimeProblemState,
        causesByID: [Int: RuntimeCauseState],
    ) -> ProblemAnnotation {
        let linkedCause = problem.causeID.flatMap { causesByID[$0] }
        let locationCode = resolvedAnatomicLocationCode(
            primary: problem.anatomicalLocation,
            fallback: linkedCause?.anatomicalLocation ?? linkedCause?.injuryLocation,
        )
        let zone = locationCode.flatMap(injuryZone(for:))
        let id = problem.problemID.map(String.init) ?? problem.primaryLabel

        return ProblemAnnotation(
            id: id,
            problemID: problem.problemID,
            title: problem.primaryLabel,
            displayName: problem.displayName,
            description: problem.description,
            isAnatomic: zone != nil,
            locationCode: locationCode,
            side: zone?.side,
            x: zone?.x,
            y: zone?.y,
            status: problem.status ?? .active,
            previousStatus: problem.previousStatus,
            severity: problem.severity,
            causeID: problem.causeID,
            causeKind: problem.causeKind,
            recommendedInterventionIDs: problem.recommendedInterventionIDs,
            adjudicationReason: problem.adjudicationReason,
            updatedAt: problem.resolvedAt ?? problem.controlledAt ?? problem.treatedAt ?? Date(),
        )
    }

    private func makeRecommendedInterventionItem(
        from recommendation: RuntimeRecommendedInterventionState,
        problemsByID: [Int: RuntimeProblemState],
    ) -> RecommendedInterventionItem {
        let fallbackTitle = recommendation.primaryLabel
        let linkedProblemTitle = recommendation.targetProblemID
            .flatMap { problemsByID[$0]?.primaryLabel }

        return RecommendedInterventionItem(
            recommendationID: recommendation.recommendationID ?? Int.random(in: 1_000_000 ... 9_999_999),
            title: fallbackTitle,
            code: recommendation.code,
            kind: recommendation.kind,
            targetProblemID: recommendation.targetProblemID,
            targetCauseID: recommendation.targetCauseID,
            targetCauseKind: recommendation.targetCauseKind,
            recommendationSource: recommendation.recommendationSource,
            validationStatus: recommendation.validationStatus,
            normalizedKind: recommendation.normalizedKind,
            normalizedCode: recommendation.normalizedCode,
            rationale: recommendation.rationale ?? linkedProblemTitle,
            priority: recommendation.priority,
            siteCode: recommendation.siteCode,
            siteLabel: recommendation.siteLabel,
            warnings: recommendation.warnings,
            contraindications: recommendation.contraindications,
        )
    }

    private func makeInterventionAnnotation(from intervention: RuntimeInterventionState) -> InterventionAnnotation? {
        let siteCode = (intervention.siteCode ?? "").uppercased()
        guard !siteCode.isEmpty, let zone = interventionZone(for: siteCode) else { return nil }

        let id = intervention.domainEventID.map(String.init)
            ?? intervention.interventionID.map(String.init)
            ?? intervention.primaryCode

        return InterventionAnnotation(
            id: id,
            interventionID: intervention.interventionID,
            interventionType: intervention.kind ?? intervention.primaryCode,
            title: intervention.title ?? intervention.primaryCode.replacingOccurrences(of: "_", with: " ").capitalized,
            siteCode: siteCode,
            siteLabel: intervention.siteLabel,
            targetProblemID: intervention.targetProblemID,
            targetCauseID: intervention.targetCauseID,
            targetCauseKind: intervention.targetCauseKind,
            validationStatus: intervention.validationStatus,
            adjudicationReason: intervention.adjudicationReason,
            warnings: intervention.warnings,
            contraindications: intervention.contraindications,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            effectiveness: intervention.effectiveness ?? "unknown",
            status: intervention.status ?? "applied",
            updatedAt: parseISODate(intervention.timestamp) ?? Date(),
        )
    }

    private func makePulseAnnotation(from pulse: RuntimePulseState) -> PulseAnnotation? {
        guard
            let location = pulse.location,
            let zone = PulseZoneMap.table[location]
        else {
            return nil
        }

        return PulseAnnotation(
            id: pulse.domainEventID.map(String.init) ?? location,
            location: location,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            present: pulse.present ?? true,
            quality: pulse.quality ?? "unknown",
            colorNormal: pulse.colorNormal ?? true,
            colorDescription: pulse.colorDescription ?? "pink",
            conditionNormal: pulse.conditionNormal ?? true,
            conditionDescription: pulse.conditionDescription ?? "dry",
            temperatureNormal: pulse.temperatureNormal ?? true,
            temperatureDescription: pulse.temperatureDescription ?? "warm",
            updatedAt: parseISODate(pulse.timestamp) ?? Date(),
        )
    }

    private func makePulseAnnotation(from event: EventEnvelope) -> PulseAnnotation? {
        let eventType = event.eventType
        let domainEventType = jsonString(event.payload["domain_event_type"])?.lowercased()
        let eventKind = jsonString(event.payload["event_kind"])?.lowercased()
        guard
            eventType == SimulationEventType.patientPulseCreated
            || eventType == SimulationEventType.patientPulseUpdated
            || domainEventType == "pulseassessment"
            || eventKind == "pulse_assessment"
        else {
            return nil
        }

        guard
            let location = jsonString(event.payload["location"]),
            let zone = PulseZoneMap.table[location]
        else {
            return nil
        }

        let domainEventID = jsonInt(event.payload["domain_event_id"]).map(String.init) ?? event.eventID
        let present = jsonBool(event.payload["present"]) ?? true
        let quality = jsonString(event.payload["quality"])
            ?? jsonString(event.payload["description"])
            ?? "strong"

        return PulseAnnotation(
            id: domainEventID,
            location: location,
            side: zone.side,
            x: zone.x,
            y: zone.y,
            present: present,
            quality: quality,
            colorNormal: jsonBool(event.payload["color_normal"]) ?? true,
            colorDescription: jsonString(event.payload["color_description"]) ?? "pink",
            conditionNormal: jsonBool(event.payload["condition_normal"]) ?? true,
            conditionDescription: jsonString(event.payload["condition_description"]) ?? "dry",
            temperatureNormal: jsonBool(event.payload["temperature_normal"]) ?? true,
            temperatureDescription: jsonString(event.payload["temperature_description"]) ?? "warm",
            updatedAt: event.createdAt,
        )
    }

    private func nextBackoffSeconds(for retryCount: Int) -> TimeInterval {
        let capped = min(retryCount + 1, 6)
        return min(pow(2.0, Double(capped)), 20)
    }

    private func isTerminalReplayFailure(_ error: Error) -> Bool {
        guard let apiError = error as? APIClientError,
              case let .http(statusCode, _, _) = apiError
        else {
            return false
        }
        return statusCode == 400 || statusCode == 404 || statusCode == 422
    }

    private func shouldRefreshRuntimeProjection(for event: EventEnvelope) -> Bool {
        SimulationEventRegistry.isRuntimeRefreshTrigger(event.eventType)
    }

    private func isCauseEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientInjuryCreated
            || eventType == SimulationEventType.patientInjuryUpdated
            || eventType == SimulationEventType.patientIllnessCreated
            || eventType == SimulationEventType.patientIllnessUpdated
    }

    private func isProblemEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientProblemCreated
            || eventType == SimulationEventType.patientProblemUpdated
    }

    private func isRecommendedInterventionEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientRecommendedInterventionCreated
            || eventType == SimulationEventType.patientRecommendedInterventionUpdated
            || eventType == SimulationEventType.patientRecommendedInterventionRemoved
    }

    private func isVitalEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientVitalCreated
            || eventType == SimulationEventType.patientVitalUpdated
    }

    private func isPulseEvent(eventType: String, payload: [String: JSONValue]) -> Bool {
        let domainEventType = jsonString(payload["domain_event_type"])?.lowercased()
        let eventKind = jsonString(payload["event_kind"])?.lowercased()
        return eventType == SimulationEventType.patientPulseCreated
            || eventType == SimulationEventType.patientPulseUpdated
            || domainEventType == "pulseassessment"
            || eventKind == "pulse_assessment"
    }

    private func isScenarioBriefEvent(eventType: String, payload: [String: JSONValue]) -> Bool {
        eventType == SimulationEventType.simulationBriefCreated
            || eventType == SimulationEventType.simulationBriefUpdated
            || payload["read_aloud_brief"] != nil
    }

    private func isAssessmentFindingEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientAssessmentFindingCreated
            || eventType == SimulationEventType.patientAssessmentFindingUpdated
            || eventType == SimulationEventType.patientAssessmentFindingRemoved
    }

    private func isDiagnosticResultEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientDiagnosticResultCreated
            || eventType == SimulationEventType.patientDiagnosticResultUpdated
    }

    private func isResourceEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientResourceUpdated
    }

    private func isDispositionEvent(eventType: String) -> Bool {
        eventType == SimulationEventType.patientDispositionUpdated
    }

    private func isNoteEvent(eventType: String, payload: [String: JSONValue]) -> Bool {
        eventType == SimulationEventType.simulationNoteCreated
            || (eventType == SimulationEventType.simulationAdjustmentUpdated
                && jsonString(payload["target"]) == "note")
    }

    private func eventPrimaryLabel(from payload: [String: JSONValue]) -> String? {
        let candidates: [JSONValue?] = [
            payload["display_name"],
            payload["title"],
            payload["label"],
            payload["name"],
            payload["code"],
        ]
        for candidate in candidates {
            if let value = jsonString(candidate), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func jsonString(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private func jsonInt(_ value: JSONValue?) -> Int? {
        guard case let .number(number)? = value else { return nil }
        return Int(number)
    }

    private func jsonBool(_ value: JSONValue?) -> Bool? {
        guard case let .bool(boolean)? = value else { return nil }
        return boolean
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private func jsonStringArray(_ value: JSONValue?) -> [String] {
        guard case let .array(values)? = value else { return [] }
        return values.compactMap(jsonString)
    }

    private func jsonIntArray(_ value: JSONValue?) -> [Int] {
        guard let value else { return [] }

        switch value {
        case let .array(values):
            return values.compactMap { element in
                if let intValue = jsonInt(element) { return intValue }
                guard case let .object(object) = element else { return nil }
                return jsonInt(object["recommendation_id"])
            }
        default:
            return []
        }
    }

    private func inferVitalType(from domainEventType: String?) -> String? {
        guard let domainEventType else { return nil }
        switch domainEventType.lowercased() {
        case "heartrate", "heart_rate":
            return "heart_rate"
        case "respiratoryrate", "respiratory_rate":
            return "respiratory_rate"
        case "spo2":
            return "spo2"
        case "etco2":
            return "etco2"
        case "bloodpressure", "blood_pressure":
            return "blood_pressure"
        case "bloodglucoselevel", "bloodglucose", "blood_glucose", "blood_glucose_level":
            return "blood_glucose"
        case "pulseassessment", "pulse_assessment":
            return "pulse_assessment"
        default:
            return nil
        }
    }

    private func isInterventionEvent(eventType: String, payload: [String: JSONValue]) -> Bool {
        if eventType == SimulationEventType.patientInterventionCreated
            || eventType == SimulationEventType.patientInterventionUpdated
        {
            return true
        }

        guard let domainType = jsonString(payload["domain_event_type"])?.lowercased() else {
            return false
        }
        return domainType.contains("intervention")
            && !domainType.contains("recommended")
            && !domainType.contains("recommendationevaluation")
    }

    private func injuryZone(for code: String) -> (side: InjuryZoneSide, x: Double, y: Double)? {
        InjuryZoneMap.table[code] ?? InterventionSiteMap.table[code]
    }

    private func resolvedAnatomicLocationCode(primary: String?, fallback: String?) -> String? {
        let candidates = [primary, fallback].compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed
        }

        for candidate in candidates {
            let normalized = candidate.uppercased()
            if InjuryZoneMap.table[normalized] != nil {
                return normalized
            }
            let collapsed = normalized.replacingOccurrences(of: " ", with: "_")
            if InjuryZoneMap.table[collapsed] != nil {
                return collapsed
            }
        }

        return candidates.first.map { $0.uppercased() }
    }
}

private enum InjuryZoneMap {
    static let table: [String: (side: InjuryZoneSide, x: Double, y: Double)] = [
        "HLA": (.front, 0.42, 0.09),
        "HRA": (.front, 0.58, 0.09),
        "HLP": (.back, 0.42, 0.09),
        "HRP": (.back, 0.58, 0.09),
        "NLA": (.front, 0.45, 0.16),
        "NRA": (.front, 0.55, 0.16),
        "NLP": (.back, 0.45, 0.16),
        "NRP": (.back, 0.55, 0.16),
        "LUA": (.front, 0.28, 0.27),
        "LLA": (.front, 0.24, 0.38),
        "LHA": (.front, 0.20, 0.50),
        "RUA": (.front, 0.72, 0.27),
        "RLA": (.front, 0.76, 0.38),
        "RHA": (.front, 0.80, 0.50),
        "TLA": (.front, 0.43, 0.30),
        "TRA": (.front, 0.57, 0.30),
        "TLP": (.back, 0.43, 0.30),
        "TRP": (.back, 0.57, 0.30),
        "ALA": (.front, 0.43, 0.40),
        "ARA": (.front, 0.57, 0.40),
        "ALP": (.back, 0.43, 0.40),
        "ARP": (.back, 0.57, 0.40),
        "LUL": (.front, 0.44, 0.57),
        "LLL": (.front, 0.42, 0.74),
        "LFT": (.front, 0.40, 0.92),
        "RUL": (.front, 0.56, 0.57),
        "RLL": (.front, 0.58, 0.74),
        "RFT": (.front, 0.60, 0.92),
        "JLX": (.front, 0.34, 0.27),
        "JRX": (.front, 0.66, 0.27),
        "JLI": (.front, 0.44, 0.51),
        "JRI": (.front, 0.56, 0.51),
        "JLN": (.front, 0.40, 0.18),
        "JRN": (.front, 0.60, 0.18),
    ]
}

private enum InterventionSiteMap {
    static let table: [String: (side: InjuryZoneSide, x: Double, y: Double)] = [
        // IV/IO access sites
        "RIGHT_ARM": (.front, 0.74, 0.33),
        "LEFT_ARM": (.front, 0.26, 0.33),
        "RIGHT_HAND": (.front, 0.80, 0.50),
        "LEFT_HAND": (.front, 0.20, 0.50),
        "RIGHT_AC": (.front, 0.70, 0.27),
        "LEFT_AC": (.front, 0.30, 0.27),
        "RIGHT_EJ": (.front, 0.58, 0.16),
        "LEFT_EJ": (.front, 0.42, 0.16),
        // IO sites
        "RIGHT_PROXIMAL_TIBIA": (.front, 0.56, 0.68),
        "LEFT_PROXIMAL_TIBIA": (.front, 0.44, 0.68),
        "RIGHT_DISTAL_FEMUR": (.front, 0.56, 0.60),
        "LEFT_DISTAL_FEMUR": (.front, 0.44, 0.60),
        "RIGHT_HUMERAL_HEAD": (.front, 0.68, 0.24),
        "LEFT_HUMERAL_HEAD": (.front, 0.32, 0.24),
        "STERNAL": (.front, 0.50, 0.28),
        // Chest procedures
        "LEFT_CHEST": (.front, 0.40, 0.30),
        "RIGHT_CHEST": (.front, 0.60, 0.30),
        "LEFT_CHEST_POSTERIOR": (.back, 0.40, 0.30),
        "RIGHT_CHEST_POSTERIOR": (.back, 0.60, 0.30),
        // Airway
        "NECK_ANTERIOR": (.front, 0.50, 0.16),
        "NASOPHARYNGEAL": (.front, 0.50, 0.08),
        "OROPHARYNGEAL": (.front, 0.50, 0.10),
        // Pelvic
        "PELVIS": (.front, 0.50, 0.48),
        // Junctional
        "LEFT_AXILLA": (.front, 0.34, 0.27),
        "RIGHT_AXILLA": (.front, 0.66, 0.27),
        "LEFT_INGUINAL": (.front, 0.44, 0.51),
        "RIGHT_INGUINAL": (.front, 0.56, 0.51),
        "LEFT_NECK": (.front, 0.43, 0.16),
        "RIGHT_NECK": (.front, 0.57, 0.16),
    ]
}

private enum PulseZoneMap {
    static let table: [String: (side: InjuryZoneSide, x: Double, y: Double)] = [
        "carotid_left": (.front, 0.43, 0.15),
        "carotid_right": (.front, 0.57, 0.15),
        "radial_left": (.front, 0.22, 0.46),
        "radial_right": (.front, 0.78, 0.46),
        "femoral_left": (.front, 0.44, 0.50),
        "femoral_right": (.front, 0.56, 0.50),
        "pedal_left": (.front, 0.40, 0.94),
        "pedal_right": (.front, 0.60, 0.94),
    ]
}
