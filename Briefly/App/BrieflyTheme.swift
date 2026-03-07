import SwiftUI

enum BrieflyTheme {
    struct TopicVisualStyle {
        let symbolName: String
        let lightGradient: [Color]
        let darkGradient: [Color]
        let lightTint: Color
        let darkTint: Color
        let lightHighlight: Color
        let darkHighlight: Color
        let lightAmbient: Color
        let darkAmbient: Color

        func gradient(for scheme: ColorScheme, emphasized: Bool = false) -> LinearGradient {
            let colors = scheme == .dark ? darkGradient : lightGradient
            let gradientColors = emphasized ? colors : colors.map { $0.opacity(scheme == .dark ? 0.9 : 0.96) }
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

        func highlight(for scheme: ColorScheme) -> Color {
            scheme == .dark ? darkHighlight : lightHighlight
        }

        func ambient(for scheme: ColorScheme) -> Color {
            scheme == .dark ? darkAmbient : lightAmbient
        }
    }

    enum Colors {

        // MARK: - Backgrounds

        /// App background – adapts to light/dark.
        static func background(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(red: 0.07, green: 0.08, blue: 0.12)
            default:
                return Color(red: 0.97, green: 0.97, blue: 0.98)
            }
        }

        /// Elevated surfaces like cards – adapts to light/dark.
        static func cardBackground(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(uiColor: .secondarySystemBackground)
            default:
                return Color.white.opacity(0.96)
            }
        }

        /// Very soft stroke / border for subtle separation.
        static func cardStroke(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.10)
            default:
                return Color.white.opacity(0.24)
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
                return Color.black.opacity(0.14)
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
                return Color.white.opacity(0.10)
            default:
                return Color.white.opacity(0.82)
            }
        }

        static func libraryAmbientPrimary(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return accentSecondary.opacity(0.18)
            default:
                return Color(red: 0.40, green: 0.54, blue: 1.0).opacity(0.12)
            }
        }

        static func libraryAmbientSecondary(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(red: 0.08, green: 0.65, blue: 0.60).opacity(0.12)
            default:
                return Color(red: 0.16, green: 0.80, blue: 0.74).opacity(0.10)
            }
        }

        static func libraryAmbientTertiary(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(red: 0.95, green: 0.53, blue: 0.28).opacity(0.08)
            default:
                return Color(red: 0.95, green: 0.55, blue: 0.28).opacity(0.08)
            }
        }

        static func topicStyle(for category: String) -> TopicVisualStyle {
            let normalized = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if normalized.contains("biology") || normalized.contains("nature") || normalized.contains("health") {
                return TopicVisualStyle(
                    symbolName: "leaf.fill",
                    lightGradient: [
                        Color(red: 0.03, green: 0.45, blue: 0.49),
                        Color(red: 0.05, green: 0.60, blue: 0.63),
                        Color(red: 0.22, green: 0.90, blue: 0.78)
                    ],
                    darkGradient: [
                        Color(red: 0.03, green: 0.20, blue: 0.22),
                        Color(red: 0.04, green: 0.28, blue: 0.29),
                        Color(red: 0.08, green: 0.44, blue: 0.39)
                    ],
                    lightTint: Color(red: 0.70, green: 1.00, blue: 0.90),
                    darkTint: Color(red: 0.56, green: 0.96, blue: 0.84),
                    lightHighlight: Color(red: 0.86, green: 1.00, blue: 0.95),
                    darkHighlight: Color(red: 0.46, green: 0.93, blue: 0.80),
                    lightAmbient: Color(red: 0.17, green: 0.83, blue: 0.73),
                    darkAmbient: Color(red: 0.09, green: 0.52, blue: 0.47)
                )
            }

            if normalized.contains("engineer") || normalized.contains("technology") || normalized.contains("math") {
                return TopicVisualStyle(
                    symbolName: "gearshape.2.fill",
                    lightGradient: [
                        Color(red: 0.08, green: 0.24, blue: 0.62),
                        Color(red: 0.11, green: 0.36, blue: 0.80),
                        Color(red: 0.36, green: 0.74, blue: 0.98)
                    ],
                    darkGradient: [
                        Color(red: 0.04, green: 0.11, blue: 0.30),
                        Color(red: 0.05, green: 0.16, blue: 0.39),
                        Color(red: 0.10, green: 0.30, blue: 0.63)
                    ],
                    lightTint: Color(red: 0.82, green: 0.92, blue: 1.00),
                    darkTint: Color(red: 0.72, green: 0.87, blue: 1.00),
                    lightHighlight: Color(red: 0.88, green: 0.95, blue: 1.00),
                    darkHighlight: Color(red: 0.57, green: 0.78, blue: 1.00),
                    lightAmbient: Color(red: 0.20, green: 0.55, blue: 0.98),
                    darkAmbient: Color(red: 0.10, green: 0.31, blue: 0.68)
                )
            }

            if normalized.contains("economic") || normalized.contains("finance") || normalized.contains("business") {
                return TopicVisualStyle(
                    symbolName: "chart.line.uptrend.xyaxis",
                    lightGradient: [
                        Color(red: 0.78, green: 0.26, blue: 0.19),
                        Color(red: 0.92, green: 0.42, blue: 0.22),
                        Color(red: 0.99, green: 0.73, blue: 0.30)
                    ],
                    darkGradient: [
                        Color(red: 0.33, green: 0.10, blue: 0.06),
                        Color(red: 0.42, green: 0.15, blue: 0.05),
                        Color(red: 0.57, green: 0.29, blue: 0.09)
                    ],
                    lightTint: Color(red: 1.00, green: 0.94, blue: 0.84),
                    darkTint: Color(red: 1.00, green: 0.88, blue: 0.68),
                    lightHighlight: Color(red: 1.00, green: 0.94, blue: 0.74),
                    darkHighlight: Color(red: 1.00, green: 0.76, blue: 0.42),
                    lightAmbient: Color(red: 0.99, green: 0.63, blue: 0.20),
                    darkAmbient: Color(red: 0.68, green: 0.31, blue: 0.10)
                )
            }

            if normalized.contains("history") || normalized.contains("culture") || normalized.contains("philosophy") {
                return TopicVisualStyle(
                    symbolName: "building.columns.fill",
                    lightGradient: [
                        Color(red: 0.53, green: 0.22, blue: 0.16),
                        Color(red: 0.66, green: 0.33, blue: 0.21),
                        Color(red: 0.89, green: 0.63, blue: 0.29)
                    ],
                    darkGradient: [
                        Color(red: 0.22, green: 0.10, blue: 0.08),
                        Color(red: 0.28, green: 0.14, blue: 0.10),
                        Color(red: 0.43, green: 0.24, blue: 0.12)
                    ],
                    lightTint: Color(red: 1.00, green: 0.93, blue: 0.86),
                    darkTint: Color(red: 0.98, green: 0.83, blue: 0.65),
                    lightHighlight: Color(red: 1.00, green: 0.91, blue: 0.78),
                    darkHighlight: Color(red: 0.96, green: 0.72, blue: 0.48),
                    lightAmbient: Color(red: 0.83, green: 0.51, blue: 0.24),
                    darkAmbient: Color(red: 0.45, green: 0.24, blue: 0.14)
                )
            }

            if normalized.contains("science") || normalized.contains("physics") || normalized.contains("chemistry") || normalized.contains("space") {
                return TopicVisualStyle(
                    symbolName: "atom",
                    lightGradient: [
                        Color(red: 0.18, green: 0.20, blue: 0.66),
                        Color(red: 0.23, green: 0.26, blue: 0.86),
                        Color(red: 0.21, green: 0.72, blue: 1.00)
                    ],
                    darkGradient: [
                        Color(red: 0.08, green: 0.08, blue: 0.30),
                        Color(red: 0.10, green: 0.10, blue: 0.38),
                        Color(red: 0.09, green: 0.28, blue: 0.61)
                    ],
                    lightTint: Color(red: 0.90, green: 0.92, blue: 1.00),
                    darkTint: Color(red: 0.84, green: 0.84, blue: 1.00),
                    lightHighlight: Color(red: 0.93, green: 0.95, blue: 1.00),
                    darkHighlight: Color(red: 0.69, green: 0.77, blue: 1.00),
                    lightAmbient: Color(red: 0.34, green: 0.47, blue: 1.00),
                    darkAmbient: Color(red: 0.14, green: 0.20, blue: 0.72)
                )
            }

            return TopicVisualStyle(
                symbolName: "book.closed.fill",
                lightGradient: [
                    Color(red: 0.22, green: 0.28, blue: 0.82),
                    Color(red: 0.28, green: 0.38, blue: 0.92),
                    Color(red: 0.62, green: 0.50, blue: 0.95)
                ],
                darkGradient: [
                    Color(red: 0.11, green: 0.14, blue: 0.35),
                    Color(red: 0.14, green: 0.18, blue: 0.42),
                    Color(red: 0.23, green: 0.17, blue: 0.49)
                ],
                lightTint: Color(red: 0.92, green: 0.93, blue: 1.00),
                darkTint: Color(red: 0.82, green: 0.86, blue: 1.00),
                lightHighlight: Color(red: 0.94, green: 0.95, blue: 1.00),
                darkHighlight: Color(red: 0.70, green: 0.77, blue: 1.00),
                lightAmbient: Color(red: 0.42, green: 0.48, blue: 1.00),
                darkAmbient: Color(red: 0.18, green: 0.21, blue: 0.66)
            )
        }
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
