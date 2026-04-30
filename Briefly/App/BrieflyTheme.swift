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

        static func background(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(red: 0.07, green: 0.08, blue: 0.12)
            default:
                return Color(red: 0.97, green: 0.97, blue: 0.98)
            }
        }

        static func cardBackground(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color(uiColor: .secondarySystemBackground)
            default:
                return Color.white.opacity(0.96)
            }
        }

        static func cardStroke(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return Color.white.opacity(0.10)
            default:
                return Color.white.opacity(0.24)
            }
        }

        // MARK: - Accents

        static let accent = Color(
            red: 0.32,
            green: 0.42,
            blue: 0.96
        )

        static func accentSoft(_ scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark:
                return accent.opacity(0.32)
            default:
                return accent.opacity(0.16)
            }
        }

        static let accentSecondary = Color(
            red: 0.55,
            green: 0.40,
            blue: 0.95
        )

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

            if normalized.contains("biology") || normalized.contains("nature") || normalized.contains("health") || normalized.contains("animal") || normalized.contains("garden") {
                return TopicVisualStyle(
                    symbolName: "leaf.fill",
                    lightGradient: [
                        Color(red: 0.05, green: 0.42, blue: 0.38),
                        Color(red: 0.07, green: 0.56, blue: 0.47),
                        Color(red: 0.34, green: 0.83, blue: 0.62)
                    ],
                    darkGradient: [
                        Color(red: 0.03, green: 0.18, blue: 0.16),
                        Color(red: 0.05, green: 0.25, blue: 0.22),
                        Color(red: 0.10, green: 0.39, blue: 0.31)
                    ],
                    lightTint: Color(red: 0.84, green: 0.98, blue: 0.91),
                    darkTint: Color(red: 0.60, green: 0.93, blue: 0.77),
                    lightHighlight: Color(red: 0.90, green: 1.00, blue: 0.95),
                    darkHighlight: Color(red: 0.50, green: 0.90, blue: 0.72),
                    lightAmbient: Color(red: 0.18, green: 0.72, blue: 0.54),
                    darkAmbient: Color(red: 0.08, green: 0.44, blue: 0.33)
                )
            }

            if normalized.contains("engineer") || normalized.contains("technology") || normalized.contains("math") || normalized.contains("artificial intelligence") || normalized.contains("program") || normalized.contains("coding") {
                return TopicVisualStyle(
                    symbolName: "gearshape.2.fill",
                    lightGradient: [
                        Color(red: 0.05, green: 0.23, blue: 0.58),
                        Color(red: 0.08, green: 0.34, blue: 0.78),
                        Color(red: 0.24, green: 0.60, blue: 0.95)
                    ],
                    darkGradient: [
                        Color(red: 0.03, green: 0.10, blue: 0.26),
                        Color(red: 0.05, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.25, blue: 0.55)
                    ],
                    lightTint: Color(red: 0.85, green: 0.92, blue: 1.00),
                    darkTint: Color(red: 0.70, green: 0.84, blue: 1.00),
                    lightHighlight: Color(red: 0.90, green: 0.95, blue: 1.00),
                    darkHighlight: Color(red: 0.54, green: 0.76, blue: 1.00),
                    lightAmbient: Color(red: 0.14, green: 0.49, blue: 0.92),
                    darkAmbient: Color(red: 0.08, green: 0.28, blue: 0.62)
                )
            }

            if normalized.contains("economic") || normalized.contains("finance") || normalized.contains("business") || normalized.contains("entrepreneur") {
                return TopicVisualStyle(
                    symbolName: "chart.line.uptrend.xyaxis",
                    lightGradient: [
                        Color(red: 0.74, green: 0.30, blue: 0.16),
                        Color(red: 0.88, green: 0.46, blue: 0.20),
                        Color(red: 0.96, green: 0.71, blue: 0.29)
                    ],
                    darkGradient: [
                        Color(red: 0.30, green: 0.12, blue: 0.06),
                        Color(red: 0.39, green: 0.17, blue: 0.06),
                        Color(red: 0.53, green: 0.28, blue: 0.10)
                    ],
                    lightTint: Color(red: 1.00, green: 0.93, blue: 0.85),
                    darkTint: Color(red: 0.98, green: 0.86, blue: 0.66),
                    lightHighlight: Color(red: 1.00, green: 0.93, blue: 0.77),
                    darkHighlight: Color(red: 0.96, green: 0.74, blue: 0.40),
                    lightAmbient: Color(red: 0.92, green: 0.58, blue: 0.19),
                    darkAmbient: Color(red: 0.62, green: 0.32, blue: 0.11)
                )
            }

            if normalized.contains("history") || normalized.contains("culture") || normalized.contains("philosophy") || normalized.contains("myth") || normalized.contains("architecture") {
                return TopicVisualStyle(
                    symbolName: "building.columns.fill",
                    lightGradient: [
                        Color(red: 0.48, green: 0.26, blue: 0.16),
                        Color(red: 0.61, green: 0.36, blue: 0.20),
                        Color(red: 0.82, green: 0.62, blue: 0.34)
                    ],
                    darkGradient: [
                        Color(red: 0.19, green: 0.11, blue: 0.08),
                        Color(red: 0.25, green: 0.15, blue: 0.10),
                        Color(red: 0.38, green: 0.24, blue: 0.13)
                    ],
                    lightTint: Color(red: 0.98, green: 0.92, blue: 0.86),
                    darkTint: Color(red: 0.94, green: 0.81, blue: 0.66),
                    lightHighlight: Color(red: 1.00, green: 0.91, blue: 0.80),
                    darkHighlight: Color(red: 0.91, green: 0.70, blue: 0.49),
                    lightAmbient: Color(red: 0.76, green: 0.50, blue: 0.25),
                    darkAmbient: Color(red: 0.41, green: 0.25, blue: 0.15)
                )
            }

            if normalized.contains("science") || normalized.contains("physics") || normalized.contains("chemistry") || normalized.contains("space") || normalized.contains("neuro") || normalized.contains("marine") {
                return TopicVisualStyle(
                    symbolName: "atom",
                    lightGradient: [
                        Color(red: 0.12, green: 0.26, blue: 0.67),
                        Color(red: 0.14, green: 0.39, blue: 0.82),
                        Color(red: 0.16, green: 0.73, blue: 0.92)
                    ],
                    darkGradient: [
                        Color(red: 0.06, green: 0.10, blue: 0.30),
                        Color(red: 0.08, green: 0.14, blue: 0.39),
                        Color(red: 0.08, green: 0.27, blue: 0.54)
                    ],
                    lightTint: Color(red: 0.87, green: 0.94, blue: 1.00),
                    darkTint: Color(red: 0.78, green: 0.87, blue: 1.00),
                    lightHighlight: Color(red: 0.90, green: 0.97, blue: 1.00),
                    darkHighlight: Color(red: 0.60, green: 0.82, blue: 1.00),
                    lightAmbient: Color(red: 0.20, green: 0.62, blue: 0.88),
                    darkAmbient: Color(red: 0.11, green: 0.33, blue: 0.58)
                )
            }

            if normalized.contains("writing") || normalized.contains("communication") || normalized.contains("language") || normalized.contains("art") || normalized.contains("creative") || normalized.contains("public speaking") {
                return TopicVisualStyle(
                    symbolName: "text.book.closed.fill",
                    lightGradient: [
                        Color(red: 0.54, green: 0.26, blue: 0.62),
                        Color(red: 0.67, green: 0.31, blue: 0.66),
                        Color(red: 0.86, green: 0.46, blue: 0.62)
                    ],
                    darkGradient: [
                        Color(red: 0.22, green: 0.11, blue: 0.28),
                        Color(red: 0.29, green: 0.14, blue: 0.32),
                        Color(red: 0.41, green: 0.18, blue: 0.34)
                    ],
                    lightTint: Color(red: 0.98, green: 0.90, blue: 0.97),
                    darkTint: Color(red: 0.91, green: 0.78, blue: 0.94),
                    lightHighlight: Color(red: 1.00, green: 0.92, blue: 0.98),
                    darkHighlight: Color(red: 0.88, green: 0.68, blue: 0.90),
                    lightAmbient: Color(red: 0.77, green: 0.35, blue: 0.67),
                    darkAmbient: Color(red: 0.40, green: 0.18, blue: 0.36)
                )
            }

            return TopicVisualStyle(
                symbolName: "book.closed.fill",
                lightGradient: [
                    Color(red: 0.32, green: 0.37, blue: 0.54),
                    Color(red: 0.40, green: 0.47, blue: 0.64),
                    Color(red: 0.56, green: 0.60, blue: 0.76)
                ],
                darkGradient: [
                    Color(red: 0.12, green: 0.15, blue: 0.24),
                    Color(red: 0.16, green: 0.19, blue: 0.29),
                    Color(red: 0.22, green: 0.25, blue: 0.36)
                ],
                lightTint: Color(red: 0.93, green: 0.95, blue: 1.00),
                darkTint: Color(red: 0.82, green: 0.86, blue: 0.95),
                lightHighlight: Color(red: 0.95, green: 0.97, blue: 1.00),
                darkHighlight: Color(red: 0.72, green: 0.78, blue: 0.92),
                lightAmbient: Color(red: 0.45, green: 0.52, blue: 0.72),
                darkAmbient: Color(red: 0.20, green: 0.24, blue: 0.40)
            )
        }
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}
