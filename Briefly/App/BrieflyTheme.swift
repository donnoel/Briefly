import SwiftUI

enum BrieflyTheme {
    struct TopicVisualStyle {
        let symbolName: String
        let lightGradient: [Color]
        let darkGradient: [Color]
        let lightTint: Color
        let darkTint: Color

        func gradient(for scheme: ColorScheme, emphasized: Bool = false) -> LinearGradient {
            let colors = scheme == .dark ? darkGradient : lightGradient
            let gradientColors = emphasized ? colors : colors.map { $0.opacity(scheme == .dark ? 0.78 : 0.9) }
            return LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        func tint(for scheme: ColorScheme) -> Color {
            scheme == .dark ? darkTint : lightTint
        }

        func softFill(for scheme: ColorScheme) -> Color {
            tint(for: scheme).opacity(scheme == .dark ? 0.24 : 0.14)
        }

        func glow(for scheme: ColorScheme) -> Color {
            tint(for: scheme).opacity(scheme == .dark ? 0.22 : 0.16)
        }
    }

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

        static func tertiaryText(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.7)
            default:
                return Color.black.opacity(0.58)
            }
        }

        static func elevatedBackground(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(uiColor: .tertiarySystemBackground)
            default:
                return Color.white.opacity(0.86)
            }
        }

        static func topicStyle(for category: String) -> TopicVisualStyle {
            let normalized = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if normalized.contains("biology") || normalized.contains("nature") || normalized.contains("health") {
                return TopicVisualStyle(
                    symbolName: "leaf.fill",
                    lightGradient: [
                        Color(red: 0.89, green: 0.98, blue: 0.96),
                        Color(red: 0.74, green: 0.93, blue: 0.85)
                    ],
                    darkGradient: [
                        Color(red: 0.10, green: 0.24, blue: 0.22),
                        Color(red: 0.07, green: 0.17, blue: 0.18)
                    ],
                    lightTint: Color(red: 0.14, green: 0.58, blue: 0.48),
                    darkTint: Color(red: 0.38, green: 0.87, blue: 0.72)
                )
            }

            if normalized.contains("engineer") || normalized.contains("technology") || normalized.contains("math") {
                return TopicVisualStyle(
                    symbolName: "gearshape.2.fill",
                    lightGradient: [
                        Color(red: 0.90, green: 0.95, blue: 1.0),
                        Color(red: 0.76, green: 0.87, blue: 1.0)
                    ],
                    darkGradient: [
                        Color(red: 0.09, green: 0.16, blue: 0.30),
                        Color(red: 0.08, green: 0.12, blue: 0.22)
                    ],
                    lightTint: Color(red: 0.20, green: 0.46, blue: 0.88),
                    darkTint: Color(red: 0.47, green: 0.68, blue: 0.98)
                )
            }

            if normalized.contains("economic") || normalized.contains("finance") || normalized.contains("business") {
                return TopicVisualStyle(
                    symbolName: "chart.line.uptrend.xyaxis",
                    lightGradient: [
                        Color(red: 1.0, green: 0.95, blue: 0.88),
                        Color(red: 1.0, green: 0.87, blue: 0.70)
                    ],
                    darkGradient: [
                        Color(red: 0.30, green: 0.17, blue: 0.07),
                        Color(red: 0.21, green: 0.11, blue: 0.04)
                    ],
                    lightTint: Color(red: 0.86, green: 0.46, blue: 0.14),
                    darkTint: Color(red: 1.0, green: 0.73, blue: 0.40)
                )
            }

            if normalized.contains("history") || normalized.contains("culture") || normalized.contains("philosophy") {
                return TopicVisualStyle(
                    symbolName: "building.columns.fill",
                    lightGradient: [
                        Color(red: 0.98, green: 0.94, blue: 0.85),
                        Color(red: 0.94, green: 0.88, blue: 0.76)
                    ],
                    darkGradient: [
                        Color(red: 0.24, green: 0.20, blue: 0.14),
                        Color(red: 0.16, green: 0.13, blue: 0.09)
                    ],
                    lightTint: Color(red: 0.70, green: 0.49, blue: 0.18),
                    darkTint: Color(red: 0.92, green: 0.77, blue: 0.47)
                )
            }

            if normalized.contains("science") || normalized.contains("physics") || normalized.contains("chemistry") || normalized.contains("space") {
                return TopicVisualStyle(
                    symbolName: "atom",
                    lightGradient: [
                        Color(red: 0.92, green: 0.94, blue: 1.0),
                        Color(red: 0.84, green: 0.86, blue: 1.0)
                    ],
                    darkGradient: [
                        Color(red: 0.15, green: 0.14, blue: 0.30),
                        Color(red: 0.11, green: 0.10, blue: 0.22)
                    ],
                    lightTint: Color(red: 0.39, green: 0.36, blue: 0.88),
                    darkTint: Color(red: 0.70, green: 0.62, blue: 1.0)
                )
            }

            return TopicVisualStyle(
                symbolName: "book.closed.fill",
                lightGradient: [
                    Color(red: 0.94, green: 0.96, blue: 1.0),
                    Color(red: 0.89, green: 0.92, blue: 1.0)
                ],
                darkGradient: [
                    Color(red: 0.13, green: 0.15, blue: 0.24),
                    Color(red: 0.10, green: 0.12, blue: 0.18)
                ],
                lightTint: accent,
                darkTint: Color(red: 0.62, green: 0.71, blue: 1.0)
            )
        }
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
