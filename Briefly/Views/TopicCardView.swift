import SwiftUI

struct TopicCardView: View {
    enum Variant {
        case standard
        case continueLearning
        case featured
    }

    @Environment(\.colorScheme) private var colorScheme

    let topic: TopicPack
    let progress: Double
    var variant: Variant = .standard

    private var style: BrieflyTheme.TopicVisualStyle {
        BrieflyTheme.Colors.topicStyle(for: topic.category)
    }

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    private var cardCount: Int {
        topic.sections.reduce(0) { $0 + $1.cards.count }
    }

    private var isEmphasized: Bool {
        variant != .standard
    }

    private var subtitleLineLimit: Int {
        switch variant {
        case .featured:
            return 3
        case .continueLearning, .standard:
            return 2
        }
    }

    private var titleFont: Font {
        switch variant {
        case .standard:
            return .system(.title3, design: .rounded).weight(.bold)
        case .continueLearning:
            return .system(.title2, design: .rounded).weight(.bold)
        case .featured:
            return .system(.largeTitle, design: .rounded).weight(.bold)
        }
    }

    private var sectionEyebrow: String {
        switch variant {
        case .standard:
            return "Topic"
        case .continueLearning:
            return progress > 0 ? "Continue Learning" : "Start Here"
        case .featured:
            return progress > 0 ? "Featured To Resume" : "Featured Topic"
        }
    }

    private var actionLabel: String {
        progress > 0 ? "Continue" : "Explore"
    }

    private var metadataFont: Font {
        switch variant {
        case .featured:
            return .system(.caption, design: .rounded).weight(.semibold)
        case .continueLearning, .standard:
            return .system(.caption2, design: .rounded).weight(.semibold)
        }
    }

    private var verticalSpacing: CGFloat {
        switch variant {
        case .featured:
            return 20
        case .continueLearning:
            return 16
        case .standard:
            return 14
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground
            decorativeSymbol

            VStack(alignment: .leading, spacing: verticalSpacing) {
                header

                VStack(alignment: .leading, spacing: isEmphasized ? 8 : 6) {
                    Text(sectionEyebrow)
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundColor(cardTertiaryText)

                    Text(topic.title)
                        .font(titleFont)
                        .foregroundColor(cardPrimaryText)
                        .lineLimit(isEmphasized ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(topic.subtitle)
                        .font(isEmphasized ? .body : .subheadline)
                        .foregroundColor(cardSecondaryText)
                        .lineLimit(subtitleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }

                metadata
                progressSection
            }
            .padding(isEmphasized ? 20 : BrieflyTheme.Layout.cardPadding)
        }
        .frame(maxWidth: .infinity, minHeight: isEmphasized ? 220 : nil, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius))
    }

    private var header: some View {
        HStack(alignment: .top) {
            Label(topic.category, systemImage: style.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(cardPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.24 : 0.22))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.18))
                        )
                )

            Spacer(minLength: 12)

            if isEmphasized {
                Label(actionLabel, systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(variant == .featured ? 0.18 : 0.14))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14))
                            )
                    )
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            statTile(
                title: topic.difficulty.rawValue,
                icon: "dial.medium",
                fillColor: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.14),
                foregroundColor: cardPrimaryText,
                strokeColor: Color.white.opacity(0.10)
            )
            statTile(
                title: "\(topic.sections.count) sections",
                icon: "square.grid.2x2",
                fillColor: Color.black.opacity(colorScheme == .dark ? 0.07 : 0.09),
                foregroundColor: cardSecondaryText,
                strokeColor: Color.white.opacity(0.08)
            )
            statTile(
                title: "\(cardCount) cards",
                icon: "rectangle.stack.fill",
                fillColor: Color.black.opacity(colorScheme == .dark ? 0.07 : 0.09),
                foregroundColor: cardSecondaryText,
                strokeColor: Color.white.opacity(0.08)
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress > 0 ? "Progress" : "Ready to start")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(cardPrimaryText)

                Spacer()

                Text(progress > 0 ? "\(progressPercent)%" : "New")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(cardPrimaryText.opacity(0.92))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.white.opacity(0.94))
                .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                .clipShape(Capsule())

            if variant == .featured {
                Text(progress > 0 ? "Pick up where you left off across sections and cards." : "Start exploring this topic with a fresh study session.")
                    .font(.caption)
                    .foregroundColor(cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
            .fill(style.gradient(for: colorScheme, emphasized: isEmphasized))
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.18 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous))
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.40 : 0.28))
                    .frame(width: isEmphasized ? 220 : 150, height: isEmphasized ? 220 : 150)
                    .blur(radius: isEmphasized ? 22 : 18)
                    .offset(x: -34, y: -44)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius - 2, style: .continuous)
                    .stroke(Color.white.opacity(isEmphasized ? 0.16 : 0.10))
                    .padding(1)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(style.ambient(for: colorScheme).opacity(colorScheme == .dark ? 0.32 : 0.22))
                    .frame(width: isEmphasized ? 170 : 120, height: isEmphasized ? 170 : 120)
                    .blur(radius: isEmphasized ? 30 : 24)
                    .offset(x: 42, y: 58)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                    .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
            )
            .shadow(
                color: style.glow(for: colorScheme),
                radius: variant == .featured ? 28 : (isEmphasized ? 22 : 14),
                x: 0,
                y: variant == .featured ? 18 : (isEmphasized ? 16 : 10)
            )
            .shadow(
                color: BrieflyTheme.Colors.shadowSoft(colorScheme),
                radius: variant == .featured ? 24 : (isEmphasized ? 18 : 10),
                x: 0,
                y: variant == .featured ? 16 : (isEmphasized ? 12 : 6)
            )
    }

    private var decorativeSymbol: some View {
        Group {
            if isEmphasized {
                ZStack {
                    Circle()
                        .fill(style.ambient(for: colorScheme).opacity(variant == .featured ? 0.34 : 0.24))
                        .frame(
                            width: variant == .featured ? 210 : 160,
                            height: variant == .featured ? 210 : 160
                        )
                        .blur(radius: variant == .featured ? 24 : 18)

                    Image(systemName: style.symbolName)
                        .font(.system(
                            size: variant == .featured ? 88 : 68,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.98),
                                    style.highlight(for: colorScheme).opacity(0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.white.opacity(0.12), radius: 18, x: 0, y: 0)
                        .opacity(variant == .featured ? 0.18 : 0.14)
                }
                .padding(.top, variant == .featured ? -20 : -4)
                .padding(.trailing, variant == .featured ? -14 : 4)
            }
        }
        .allowsHitTesting(false)
    }

    private var cardPrimaryText: Color {
        Color.white.opacity(0.98)
    }

    private var cardSecondaryText: Color {
        Color.white.opacity(0.82)
    }

    private var cardTertiaryText: Color {
        Color.white.opacity(0.70)
    }

    private func statTile(title: String, icon: String, fillColor: Color, foregroundColor: Color, strokeColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: variant == .featured ? 11 : 10, weight: .semibold))

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(metadataFont)
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, variant == .featured ? 10 : 9)
        .padding(.vertical, variant == .featured ? 9 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeColor)
                )
        )
    }
}
