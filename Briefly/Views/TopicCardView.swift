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

    private var titleLineLimit: Int {
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
            return .system(size: 36, weight: .bold, design: .rounded)
        }
    }

    private var sectionEyebrow: String {
        switch variant {
        case .standard:
            return "Topic"
        case .continueLearning:
            return ""
        case .featured:
            return progress > 0 ? "Featured To Resume" : "Editorial Pick"
        }
    }

    private var actionLabel: String {
        progress > 0 ? "Continue" : "Explore"
    }

    private var showsEyebrow: Bool {
        !sectionEyebrow.isEmpty
    }

    private var showsActionChip: Bool {
        variant == .featured
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
            return 24
        case .continueLearning:
            return 14
        case .standard:
            return 14
        }
    }

    private var cardPadding: CGFloat {
        switch variant {
        case .featured:
            return 24
        case .continueLearning:
            return 20
        case .standard:
            return BrieflyTheme.Layout.cardPadding
        }
    }

    private var minimumCardHeight: CGFloat? {
        switch variant {
        case .featured:
            return 250
        case .continueLearning:
            return 220
        case .standard:
            return nil
        }
    }

    private var subtitleFont: Font {
        switch variant {
        case .featured:
            return .body
        case .continueLearning, .standard:
            return .subheadline
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground
            decorativeSymbol

            VStack(alignment: .leading, spacing: verticalSpacing) {
                header

                VStack(alignment: .leading, spacing: isEmphasized ? 8 : 6) {
                    if showsEyebrow {
                        Text(sectionEyebrow)
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(1.0)
                            .foregroundColor(cardTertiaryText)
                    }

                    Text(topic.title)
                        .font(titleFont)
                        .foregroundColor(cardPrimaryText)
                        .lineLimit(titleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(topic.subtitle)
                        .font(subtitleFont)
                        .foregroundColor(cardSecondaryText)
                        .lineLimit(subtitleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }

                metadata
                    .padding(.top, variant == .featured ? 8 : 0)
                progressSection
            }
            .padding(cardPadding)
        }
        .frame(maxWidth: .infinity, minHeight: minimumCardHeight, alignment: .leading)
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

            if showsActionChip {
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
        VStack(alignment: .leading, spacing: variant == .featured ? 12 : 8) {
            HStack(alignment: .firstTextBaseline) {
                if variant != .continueLearning {
                    Text(progress > 0 ? "Progress" : "New Topic")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(cardPrimaryText)
                }

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
        .padding(.top, variant == .featured ? 4 : 0)
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
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.38 : 0.26))
                    .frame(width: variant == .featured ? 250 : (isEmphasized ? 220 : 150), height: variant == .featured ? 250 : (isEmphasized ? 220 : 150))
                    .blur(radius: variant == .featured ? 28 : (isEmphasized ? 22 : 18))
                    .offset(x: -38, y: -52)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius - 2, style: .continuous)
                    .stroke(Color.white.opacity(isEmphasized ? 0.16 : 0.10))
                    .padding(1)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(style.ambient(for: colorScheme).opacity(variant == .featured ? 0.28 : (colorScheme == .dark ? 0.32 : 0.22)))
                    .frame(width: variant == .featured ? 190 : (isEmphasized ? 170 : 120), height: variant == .featured ? 190 : (isEmphasized ? 170 : 120))
                    .blur(radius: variant == .featured ? 34 : (isEmphasized ? 30 : 24))
                    .offset(x: 46, y: 64)
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
                        .fill(style.ambient(for: colorScheme).opacity(variant == .featured ? 0.30 : 0.20))
                        .frame(
                            width: variant == .featured ? 250 : 154,
                            height: variant == .featured ? 250 : 154
                        )
                        .blur(radius: variant == .featured ? 28 : 18)

                    Image(systemName: style.symbolName)
                        .font(.system(
                            size: variant == .featured ? 108 : 62,
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
                        .opacity(variant == .featured ? 0.16 : 0.11)
                }
                .padding(.top, variant == .featured ? -30 : -6)
                .padding(.trailing, variant == .featured ? -24 : 0)
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
