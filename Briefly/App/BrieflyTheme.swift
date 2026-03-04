import SwiftUI

enum BrieflyTheme {
    enum Colors {

        // MARK: - Backgrounds

        /// App background – adapts to light/dark.
        static func background(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(uiColor: .systemGroupedBackground)
            default:
                return Color(red: 0.95, green: 0.96, blue: 1.00)
            }
        }

        /// Elevated surfaces like cards – adapts to light/dark.
        static func cardBackground(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(uiColor: .secondarySystemBackground)
            default:
                return Color.white.opacity(0.94)
            }
        }

        /// Very soft stroke / border for subtle separation.
        static func cardStroke(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.06)
            default:
                return Color.black.opacity(0.04)
            }
        }

        // MARK: - Accents

        /// Primary accent for buttons, chips, and key highlights.
        static let accent = Color(
            red: 0.32,
            green: 0.42,
            blue: 0.96
        )

        /// Soft accent background for pills and tags.
        static func accentSoft(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return accent.opacity(0.32)
            default:
                return accent.opacity(0.16)
            }
        }

        /// Secondary accent (used sparingly for gradients, etc.).
        static let accentSecondary = Color(
            red: 0.55,
            green: 0.40,
            blue: 0.95
        )

        /// Shadow for floating cards.
        static func shadowSoft(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.black.opacity(0.6)
            default:
                return Color.black.opacity(0.10)
            }
        }

        // MARK: - Text

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary

        // MARK: - Card gradients

        static func cardGradientFront(_ scheme: ColorScheme) -> LinearGradient {
            switch scheme {
            case .dark:
                return LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.11, blue: 0.16),
                        Color(red: 0.08, green: 0.09, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color(red: 0.94, green: 0.95, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        static func cardGradientBack(_ scheme: ColorScheme) -> LinearGradient {
            switch scheme {
            case .dark:
                return LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.16, blue: 0.26),
                        Color(red: 0.10, green: 0.11, blue: 0.19)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                return LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.92, blue: 1.0),
                        Color(red: 0.80, green: 0.84, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        // MARK: - Deck surfaces

        static func deckBackgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
            switch scheme {
            case .dark:
                return LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.12),
                        Color(red: 0.09, green: 0.10, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                return LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.95, blue: 1.00),
                        Color(red: 0.90, green: 0.92, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        static func deckHeaderGradient(_ scheme: ColorScheme) -> LinearGradient {
            switch scheme {
            case .dark:
                return LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.15, blue: 0.22),
                        Color(red: 0.10, green: 0.12, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color(red: 0.93, green: 0.95, blue: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        static func deckActionTray(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.96)
            default:
                return Color.white.opacity(0.92)
            }
        }

        static func progressTrack(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.15)
            default:
                return Color.black.opacity(0.08)
            }
        }

        static func cardHighlight(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.10)
            default:
                return Color.white.opacity(0.80)
            }
        }
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
