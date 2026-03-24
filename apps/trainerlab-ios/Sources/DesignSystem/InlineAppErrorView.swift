import Networking
import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public struct InlineAppErrorView: View {
    private let error: PresentableAppError
    private let actionLabel: String?
    private let action: (() -> Void)?
    @State private var isShowingDebugDetails = false

    public init(
        error: PresentableAppError,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil,
    ) {
        self.error = error
        self.actionLabel = actionLabel
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TrainerLabTheme.danger)

                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(error.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let label = resolvedActionLabel, let action {
                    Button(label, action: action)
                        .buttonStyle(.bordered)
                }
            }

            #if DEBUG
                if !error.debugDetailsText.isEmpty {
                    DisclosureGroup(isExpanded: $isShowingDebugDetails) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error.debugDetailsText)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Button("Copy Debug Details") {
                                copyToPasteboard(error.debugDetailsText)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    } label: {
                        Text("Debug Details")
                            .font(.caption.weight(.semibold))
                    }
                }
            #endif
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrainerLabTheme.setupSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TrainerLabTheme.danger.opacity(0.35), lineWidth: 1),
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resolvedActionLabel: String? {
        actionLabel ?? error.recoveryActionLabel
    }

    private func copyToPasteboard(_ value: String) {
        #if canImport(UIKit)
            UIPasteboard.general.string = value
        #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}
