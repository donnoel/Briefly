import SwiftUI

enum BrieflyTheme {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let cardBackground = Color.white.opacity(0.9)
        static let accent = Color.blue
        static let accentSoft = Color.blue.opacity(0.12)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
