import Sessions
import SharedModels
import SwiftUI

struct VoiceActionSheet: View {
    @ObservedObject var store: RunSessionStore
    @StateObject private var capture = VoiceActionCapture()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: VoiceActionDraft?
    @State private var showComposer = false
    @State private var selectedType = ""
    @State private var submitted = false
    @State private var confirmedPerformed = false
    @State private var captureSimulationID: Int?

    private var canRecord: Bool {
        store.state.commandChannelAvailable
            && store.dashboardPresentation?.capabilities.canRecordLearnerAction == true
            && captureSimulationID == store.state.session?.simulationID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Describe one action the learner performed. Review the text and action details before confirming.")
                    Button {
                        if capture.isRecording || capture.isStarting {
                            capture.stop()
                            freezeDraft()
                        } else {
                            draft = nil
                            confirmedPerformed = false
                            Task { await capture.start() }
                        }
                    } label: {
                        Label(capture.isRecording ? "Stop dictation" : capture.isStarting ? "Cancel starting" : "Dictate action",
                              systemImage: capture.isRecording ? "stop.circle.fill" : "mic.fill")
                            .frame(minHeight: 44)
                    }
                    .disabled(!canRecord)
                    .accessibilityIdentifier("trainer-voice-capture")
                    if capture.isRecording {
                        Text("Listening · up to 30 seconds")
                        Text(capture.transcript.isEmpty ? "Speak now…" : capture.transcript)
                    }
                    if let error = capture.errorMessage {
                        Text(error).foregroundStyle(.secondary)
                    }
                }
                if draft != nil {
                    Section("Review transcript") {
                        TextField("What happened?", text: Binding(
                            get: { draft?.reviewedTranscript ?? "" },
                            set: { draft?.reviewedTranscript = String($0.prefix(2000)); confirmedPerformed = false },
                        ), axis: .vertical)
                        .lineLimit(3 ... 8)
                        if draft?.needsClarification == true {
                            Text("This may describe an action that did not happen or is only planned. Clarify what actually occurred before continuing.")
                        }
                        Toggle("I observed this action being performed", isOn: $confirmedPerformed)
                    }
                    Section("Review one action") {
                        if let draft {
                            ForEach(draft.candidates(in: store.interventionDictionary)) { candidate in
                                Button("Review \(candidate.label)") {
                                    selectedType = candidate.interventionType
                                    showComposer = true
                                }
                            }
                        }
                        Button("Choose action manually") {
                            selectedType = ""
                            showComposer = true
                        }
                    }
                    .disabled(!confirmedPerformed || draft?.canReview != true || !canRecord || submitted)
                    Text("Nothing has been recorded in the scenario. Multiple actions must be reviewed separately.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Dictate Learner Action")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { capture.cancel(); dismiss() }
                }
            }
            .sheet(isPresented: $showComposer) {
                InterventionComposerSheet(
                    dictionary: store.interventionDictionary,
                    problems: store.state.problemAnnotations,
                    recommendations: [],
                    interventions: store.state.interventionAnnotations,
                    prefilledTargetProblemID: nil,
                    initialPrefill: InterventionComposerPrefill(
                        interventionType: selectedType, effectiveness: .unknown,
                    ),
                    canMutate: canRecord && !submitted,
                    confirmationTitle: "Confirm performed",
                    requiresTarget: true,
                ) { type, site, target, status, effectiveness, notes, mode in
                    guard !submitted, canRecord, confirmedPerformed, let draft, draft.canReview else { return }
                    submitted = true
                    store.addIntervention(
                        interventionType: type, siteCode: site, targetProblemID: target,
                        status: status, effectiveness: effectiveness, notes: notes,
                        tourniquetApplicationMode: mode, voiceProvenance: draft.confirmedProvenance,
                    )
                    dismiss()
                }
            }
        }
        .onAppear {
            if captureSimulationID == nil { captureSimulationID = store.state.session?.simulationID }
        }
        .onChange(of: store.state.session?.simulationID) { _, simulationID in
            if captureSimulationID != simulationID { capture.cancel(); dismiss() }
        }
        .onChange(of: capture.isRecording) { _, recording in
            if !recording { freezeDraft() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { capture.stop(); freezeDraft() }
        }
        .onChange(of: canRecord) { _, allowed in
            if !allowed { capture.stop(); freezeDraft() }
        }
        .onDisappear { capture.cancel() }
    }

    private func freezeDraft() {
        guard !capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, draft == nil else { return }
        draft = VoiceActionDraft(transcript: capture.transcript)
    }
}
