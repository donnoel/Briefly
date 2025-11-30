import SwiftUI

enum BrieflyTheme {
    enum Colors {
        /// App background – soft, slightly cool, easy on the eyes.
        static let background = Color(
            red: 0.95,
            green: 0.96,
            blue: 1.00
        )

        /// Elevated surfaces like cards.
        static let cardBackground = Color.white.opacity(0.94)

        /// Very soft stroke / border for subtle separation.
        static let cardStroke = Color.black.opacity(0.04)

        /// Primary accent for buttons, chips, and key highlights.
        static let accent = Color(
            red: 0.32,
            green: 0.42,
            blue: 0.96
        )

        /// Soft accent background for pills and tags.
        static let accentSoft = accent.opacity(0.16)

        /// Secondary accent (used sparingly for gradients, etc.).
        static let accentSecondary = Color(
            red: 0.55,
            green: 0.40,
            blue: 0.95
        )

        /// Shadow for floating cards.
        static let shadowSoft = Color.black.opacity(0.10)

        /// Text colors – keep these dynamic for Light/Dark & accessibility.
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary

        /// Gradients for cards (front vs back state).
        static let cardGradientFront = LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color(red: 0.94, green: 0.95, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cardGradientBack = LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.92, blue: 1.0),
                Color(red: 0.80, green: 0.84, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
