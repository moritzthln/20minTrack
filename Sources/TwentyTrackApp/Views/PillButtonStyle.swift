import SwiftUI

/// Quiet capsule button (Timer port) — used for secondary actions.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(.vertical, 6)
            .padding(.horizontal, 13)
            .background(
                Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07))
            )
            .contentShape(Capsule())
    }
}
