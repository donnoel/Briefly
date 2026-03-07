import SwiftUI

struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.12 : 0),
                radius: configuration.isPressed ? 18 : 0,
                x: 0,
                y: configuration.isPressed ? 10 : 0
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
