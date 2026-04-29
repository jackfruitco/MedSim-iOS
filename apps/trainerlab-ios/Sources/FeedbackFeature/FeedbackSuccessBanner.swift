import DesignSystem
import SwiftUI

public struct FeedbackSuccessBanner: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .trainerGlassSurface(
            role: .floatingOverlay,
            cornerRadius: 14,
            tint: Color.green.opacity(0.14),
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}
