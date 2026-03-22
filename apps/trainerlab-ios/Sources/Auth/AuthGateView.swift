import AuthenticationServices
import DesignSystem
import Networking
import SwiftUI

public struct AuthGateView: View {
    private enum Field: Hashable {
        case email
        case password
    }

    @ObservedObject private var viewModel: AuthViewModel
    private let appTitle: String
    private let appSubtitle: String
    private let environmentLabel: String
    private let onOpenEnvironmentSwitcher: () -> Void
    private let appleSignInCoordinator = AppleSignInCoordinator()
    @FocusState private var focusedField: Field?

    public init(
        viewModel: AuthViewModel,
        appTitle: String = "TrainerLab",
        appSubtitle: String = "Instructor Console",
        environmentLabel: String,
        onOpenEnvironmentSwitcher: @escaping () -> Void,
    ) {
        self.viewModel = viewModel
        self.appTitle = appTitle
        self.appSubtitle = appSubtitle
        self.environmentLabel = environmentLabel
        self.onOpenEnvironmentSwitcher = onOpenEnvironmentSwitcher
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [TrainerLabTheme.setupBackground, TrainerLabTheme.setupSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "cross.case.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(TrainerLabTheme.accentBlue)

                Text(appTitle)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("auth-brand-title")

                Text(appSubtitle)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("auth-brand-subtitle")

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        appleSignInCoordinator.configure(request)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 46)
                    .disabled(!canStartAppleSignIn)

                    TextField(
                        "Invitation Token (optional for first-time Apple sign-up)",
                        text: $viewModel.invitationToken
                    )
                    .authInvitationFieldModifiers()
                    .textFieldStyle(.roundedBorder)

                    divider(label: "or use email and password")

                    TextField("Email", text: $viewModel.email)
                        .authEmailFieldModifiers()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $viewModel.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            submitIfPossible()
                        }
                        .textFieldStyle(.roundedBorder)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(TrainerLabTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.footnote)
                    }

                    Button {
                        submitIfPossible()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                }
                .trainerCardStyle(background: TrainerLabTheme.setupSurface)
                .frame(maxWidth: 460)

                Text(environmentLabel)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .onLongPressGesture(minimumDuration: 1.2, perform: onOpenEnvironmentSwitcher)
            }
            .padding(30)
        }
        .background(
            KeyboardCommandBridge(
                onTab: {
                    moveFocusForward()
                },
                onShiftTab: {
                    moveFocusBackward()
                },
                onEnter: {
                    if focusedField == .password {
                        submitIfPossible()
                    } else {
                        moveFocusForward()
                    }
                },
            )
            .frame(width: 0, height: 0),
        )
        .sheet(isPresented: appleSignupSheetPresented) {
            if let pendingSignup = viewModel.pendingAppleSignup {
                AppleSignupCompletionSheet(
                    pendingSignup: pendingSignup,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    onCancel: {
                        viewModel.cancelAppleSignup()
                    },
                    onComplete: { roleID, givenName, familyName in
                        Task {
                            await viewModel.completeAppleSignup(
                                roleID: roleID,
                                givenName: givenName,
                                familyName: familyName
                            )
                        }
                    }
                )
            }
        }
        .onAppear {
            if focusedField == nil {
                focusedField = .email
            }
        }
    }

    private var canSubmit: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty && !viewModel.isLoading
    }

    private var canStartAppleSignIn: Bool {
        !viewModel.isLoading
    }

    private var appleSignupSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAppleSignup != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelAppleSignup()
                }
            }
        )
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        Task { await viewModel.signIn() }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        do {
            let credential = try appleSignInCoordinator.credential(from: result)
            Task {
                await viewModel.signInWithApple(credential)
            }
        } catch {
            viewModel.setErrorMessage(error.localizedDescription)
        }
    }

    private func moveFocusForward() {
        switch focusedField {
        case .email:
            focusedField = .password
        case .password:
            submitIfPossible()
        case .none:
            focusedField = .email
        }
    }

    private func moveFocusBackward() {
        switch focusedField {
        case .password:
            focusedField = .email
        default:
            focusedField = .email
        }
    }

    private func divider(label: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(TrainerLabTheme.tacticalBorder.opacity(0.45))
                .frame(height: 1)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(TrainerLabTheme.tacticalBorder.opacity(0.45))
                .frame(height: 1)
        }
    }
}

private struct AppleSignupCompletionSheet: View {
    let pendingSignup: PendingAppleSignup
    let isLoading: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onComplete: (_ roleID: Int?, _ givenName: String, _ familyName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var givenName: String
    @State private var familyName: String
    @State private var selectedRoleID: Int?

    init(
        pendingSignup: PendingAppleSignup,
        isLoading: Bool,
        errorMessage: String?,
        onCancel: @escaping () -> Void,
        onComplete: @escaping (_ roleID: Int?, _ givenName: String, _ familyName: String) -> Void
    ) {
        self.pendingSignup = pendingSignup
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onComplete = onComplete
        _givenName = State(initialValue: pendingSignup.givenName)
        _familyName = State(initialValue: pendingSignup.familyName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Email", value: pendingSignup.email)
                }

                Section("Profile") {
                    TextField("First Name", text: $givenName)
                    TextField("Last Name", text: $familyName)
                    Picker("Role", selection: $selectedRoleID) {
                        Text("Select a role...").tag(Int?.none)
                        ForEach(pendingSignup.roles) { role in
                            Text(role.title).tag(Optional(role.id))
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(TrainerLabTheme.danger)
                    }
                }
            }
            .navigationTitle("Complete Apple Sign-In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onComplete(selectedRoleID, givenName, familyName)
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Continue")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func authEmailFieldModifiers() -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
        #else
            self
        #endif
    }

    @ViewBuilder
    func authInvitationFieldModifiers() -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        #else
            self
        #endif
    }
}

#if os(iOS)
    import UIKit

    private struct KeyboardCommandBridge: UIViewRepresentable {
        let onTab: () -> Void
        let onShiftTab: () -> Void
        let onEnter: () -> Void

        func makeUIView(context _: Context) -> KeyboardCommandView {
            let view = KeyboardCommandView()
            view.onTab = onTab
            view.onShiftTab = onShiftTab
            view.onEnter = onEnter
            return view
        }

        func updateUIView(_ uiView: KeyboardCommandView, context _: Context) {
            uiView.onTab = onTab
            uiView.onShiftTab = onShiftTab
            uiView.onEnter = onEnter
        }
    }

    private final class KeyboardCommandView: UIView {
        var onTab: (() -> Void)?
        var onShiftTab: (() -> Void)?
        var onEnter: (() -> Void)?

        override var canBecomeFirstResponder: Bool {
            true
        }

        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTab)),
                UIKeyCommand(input: "\t", modifierFlags: [.shift], action: #selector(handleShiftTab)),
                UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleEnter)),
            ]
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.becomeFirstResponder()
            }
        }

        @objc private func handleTab() {
            onTab?()
        }

        @objc private func handleShiftTab() {
            onShiftTab?()
        }

        @objc private func handleEnter() {
            onEnter?()
        }
    }
#else
    private struct KeyboardCommandBridge: View {
        let onTab: () -> Void
        let onShiftTab: () -> Void
        let onEnter: () -> Void

        var body: some View {
            EmptyView()
        }
    }
#endif
