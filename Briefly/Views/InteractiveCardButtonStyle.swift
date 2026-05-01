import SwiftUI

struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.968 : 1)
            .saturation(configuration.isPressed ? 1.04 : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.12 : 0),
                radius: configuration.isPressed ? 16 : 0,
                x: 0,
                y: configuration.isPressed ? 8 : 0
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.74), value: configuration.isPressed)
    }
}
