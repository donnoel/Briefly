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
        BrieflyTheme.Colors.topicStyle(
            for: topic.category,
            context: "\(topic.title) \(topic.subtitle)"
        )
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

    private var titleLineLimit: Int {
        switch variant {
        case .featured:
            return 2
        case .continueLearning, .standard:
            return 2
        }
    }

    private var subtitleLineLimit: Int {
        switch variant {
        case .featured:
            return 2
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
            return .system(size: 34, weight: .bold, design: .rounded)
        }
    }

    private var subtitleFont: Font {
        switch variant {
        case .featured:
            return .title3.weight(.medium)
        case .continueLearning, .standard:
            return .subheadline
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

    private var showsCategoryChip: Bool {
        variant == .featured
    }

    private var showsHeader: Bool {
        showsCategoryChip || showsActionChip
    }

    private var metadataFont: Font {
        switch variant {
        case .featured:
            return .system(.caption, design: .rounded).weight(.semibold)
        case .continueLearning, .standard:
            return .system(.caption2, design: .rounded).weight(.medium)
        }
    }

    private var verticalSpacing: CGFloat {
        switch variant {
        case .featured:
            return 20
        case .continueLearning, .standard:
            return 12
        }
    }

    private var cardPadding: CGFloat {
        switch variant {
        case .featured:
            return 24
        case .continueLearning:
            return 18
        case .standard:
            return 18
        }
    }

    private var cardHeight: CGFloat {
        switch variant {
        case .featured:
            return 250
        case .continueLearning, .standard:
            return 220
        }
    }

    private var titleAreaHeight: CGFloat {
        switch variant {
        case .featured:
            return 98
        case .continueLearning, .standard:
            return 96
        }
    }

    private var metadataHeight: CGFloat {
        switch variant {
        case .featured:
            return 38
        case .continueLearning, .standard:
            return 32
        }
    }

    private var progressLabel: String {
        progress > 0 ? "Progress" : "New Topic"
    }

    private var progressValueLabel: String {
        progress > 0 ? "\(progressPercent)%" : "New"
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground
            decorativeSymbol

            VStack(alignment: .leading, spacing: verticalSpacing) {
                if showsHeader {
                    header
                }

                titleBlock
                    .frame(
                        maxWidth: .infinity,
                        minHeight: titleAreaHeight,
                        maxHeight: titleAreaHeight,
                        alignment: .topLeading
                    )

                metadata
                    .frame(height: metadataHeight, alignment: .leading)

                Spacer(minLength: 0)

                progressSection
            }
            .padding(cardPadding)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .leading)
        .clipShape(cardShape)
        .contentShape(cardShape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(progress > 0 ? "Continues this topic." : "Opens this topic.")
    }

    private var header: some View {
        HStack(alignment: .top) {
            if showsCategoryChip {
                categoryChip
            }

            Spacer(minLength: 12)

            if showsActionChip {
                actionChip
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var categoryChip: some View {
        Label(topic.category, systemImage: style.symbolName)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(cardPrimaryText)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.18))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.14))
                    )
            )
    }

    private var actionChip: some View {
        Label(actionLabel, systemImage: "arrow.right")
            .font(.caption.weight(.semibold))
            .foregroundColor(cardPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10))
                    )
            )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(topic.subtitle)
                .font(subtitleFont)
                .foregroundColor(cardSecondaryText)
                .lineLimit(subtitleLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: variant == .featured ? 8 : 6) {
            statTile(
                title: topic.difficulty.rawValue,
                icon: "dial.medium",
                fillColor: primaryMetadataFill,
                foregroundColor: cardPrimaryText,
                strokeColor: primaryMetadataStroke
            )

            if variant == .featured {
                statTile(
                    title: "\(topic.sections.count) sections",
                    icon: "square.grid.2x2",
                    fillColor: secondaryMetadataFill,
                    foregroundColor: cardSecondaryText,
                    strokeColor: secondaryMetadataStroke
                )
            }

            statTile(
                title: "\(cardCount) cards",
                icon: "rectangle.stack.fill",
                fillColor: secondaryMetadataFill,
                foregroundColor: cardSecondaryText,
                strokeColor: secondaryMetadataStroke
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: variant == .featured ? 10 : 8) {
            HStack(alignment: .firstTextBaseline) {
                if variant != .continueLearning {
                    Text(progressLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(cardPrimaryText)
                }

                Spacer()

                Text(progressValueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(cardPrimaryText.opacity(0.92))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.white.opacity(0.94))
                .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.14))
                .clipShape(Capsule())

            if variant == .featured {
                Text(
                    progress > 0
                    ? "Pick up where you left off across sections and cards."
                    : "Start exploring this topic with a fresh study session."
                )
                .font(.caption)
                .foregroundColor(cardSecondaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cardBackground: some View {
        cardShape
            .fill(style.gradient(for: colorScheme, emphasized: isEmphasized))
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.16 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(cardShape)
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.30 : 0.20))
                    .frame(
                        width: variant == .featured ? 220 : (isEmphasized ? 180 : 136),
                        height: variant == .featured ? 220 : (isEmphasized ? 180 : 136)
                    )
                    .blur(radius: variant == .featured ? 24 : (isEmphasized ? 18 : 14))
                    .offset(x: -30, y: -42)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(style.ambient(for: colorScheme).opacity(variant == .featured ? 0.24 : (colorScheme == .dark ? 0.24 : 0.16)))
                    .frame(
                        width: variant == .featured ? 176 : (isEmphasized ? 150 : 110),
                        height: variant == .featured ? 176 : (isEmphasized ? 150 : 110)
                    )
                    .blur(radius: variant == .featured ? 28 : (isEmphasized ? 22 : 18))
                    .offset(x: 40, y: 56)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius - 2, style: .continuous)
                    .stroke(Color.white.opacity(isEmphasized ? 0.12 : 0.08))
                    .padding(1)
            }
            .overlay(
                cardShape.stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
            )
            .shadow(
                color: style.glow(for: colorScheme),
                radius: variant == .featured ? 24 : (isEmphasized ? 18 : 12),
                x: 0,
                y: variant == .featured ? 14 : (isEmphasized ? 12 : 8)
            )
            .shadow(
                color: BrieflyTheme.Colors.shadowSoft(colorScheme),
                radius: variant == .featured ? 22 : (isEmphasized ? 16 : 10),
                x: 0,
                y: variant == .featured ? 14 : (isEmphasized ? 10 : 6)
            )
    }

    private var decorativeSymbol: some View {
        Group {
            if variant == .featured {
                ZStack {
                    Circle()
                        .fill(style.ambient(for: colorScheme).opacity(0.24))
                        .frame(width: 220, height: 220)
                        .blur(radius: 24)

                    Image(systemName: style.symbolName)
                        .font(.system(
                            size: 96,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.94),
                                    style.highlight(for: colorScheme).opacity(0.76)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.12)
                }
                .padding(.top, -26)
                .padding(.trailing, -20)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [topic.title, topic.subtitle, topic.difficulty.rawValue]

        if variant == .featured {
            parts.append("\(topic.sections.count) sections")
        }

        parts.append("\(cardCount) cards")

        if progress > 0 {
            parts.append("\(progressPercent) percent complete")
        } else {
            parts.append("New topic")
        }

        return parts.joined(separator: ", ")
    }

    private var primaryMetadataFill: Color {
        variant == .featured
            ? Color.white.opacity(colorScheme == .dark ? 0.10 : 0.12)
            : Color.white.opacity(colorScheme == .dark ? 0.08 : 0.10)
    }

    private var secondaryMetadataFill: Color {
        variant == .featured
            ? Color.black.opacity(colorScheme == .dark ? 0.06 : 0.08)
            : Color.black.opacity(colorScheme == .dark ? 0.05 : 0.06)
    }

    private var primaryMetadataStroke: Color {
        Color.white.opacity(variant == .featured ? 0.08 : 0.05)
    }

    private var secondaryMetadataStroke: Color {
        Color.white.opacity(variant == .featured ? 0.06 : 0.04)
    }

    private var cardPrimaryText: Color {
        Color.white.opacity(0.98)
    }

    private var cardSecondaryText: Color {
        Color.white.opacity(0.82)
    }

    private var cardTertiaryText: Color {
        Color.white.opacity(0.68)
    }

    private func statTile(title: String, icon: String, fillColor: Color, foregroundColor: Color, strokeColor: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: variant == .featured ? 11 : 9, weight: .medium))

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(metadataFont)
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, variant == .featured ? 10 : 8)
        .padding(.vertical, variant == .featured ? 9 : 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(strokeColor)
                )
        )
    }
}
