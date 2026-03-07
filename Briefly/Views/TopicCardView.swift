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
        isEmphasized ? 3 : 2
    }

    private var titleFont: Font {
        switch variant {
        case .standard:
            return .title3.weight(.semibold)
        case .continueLearning:
            return .title2.weight(.semibold)
        case .featured:
            return .largeTitle.weight(.bold)
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

    var body: some View {
        VStack(alignment: .leading, spacing: isEmphasized ? 18 : 14) {
            header

            VStack(alignment: .leading, spacing: isEmphasized ? 8 : 6) {
                Text(sectionEyebrow)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(BrieflyTheme.Colors.tertiaryText(colorScheme))

                Text(topic.title)
                    .font(titleFont)
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                    .lineLimit(isEmphasized ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(topic.subtitle)
                    .font(isEmphasized ? .body : .subheadline)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metadata
            progressSection
        }
        .padding(isEmphasized ? 20 : BrieflyTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, minHeight: isEmphasized ? 220 : nil, alignment: .leading)
        .background(
            cardBackground
        )
        .contentShape(RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius))
    }

    private var header: some View {
        HStack(alignment: .top) {
            Label(topic.category, systemImage: style.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(style.tint(for: colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(style.softFill(for: colorScheme))
                )

            Spacer(minLength: 12)

            if isEmphasized {
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(style.tint(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(BrieflyTheme.Colors.elevatedBackground(colorScheme))
                    )
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            chip(title: topic.difficulty.rawValue, icon: "dial.medium", fillColor: BrieflyTheme.Colors.elevatedBackground(colorScheme), foregroundColor: style.tint(for: colorScheme))
            chip(title: "\(topic.sections.count) sections", icon: "square.grid.2x2", fillColor: BrieflyTheme.Colors.elevatedBackground(colorScheme), foregroundColor: BrieflyTheme.Colors.textSecondary)
            chip(title: "\(cardCount) cards", icon: "rectangle.stack.fill", fillColor: BrieflyTheme.Colors.elevatedBackground(colorScheme), foregroundColor: BrieflyTheme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress > 0 ? "Progress" : "Ready to start")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)

                Spacer()

                Text(progress > 0 ? "\(progressPercent)%" : "New")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(style.tint(for: colorScheme))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(style.tint(for: colorScheme))
                .background(BrieflyTheme.Colors.progressTrack(colorScheme))

            if isEmphasized {
                Text(progress > 0 ? "Pick up where you left off across sections and cards." : "Start exploring this topic with a fresh study session.")
                    .font(.caption)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
            .fill(style.gradient(for: colorScheme, emphasized: isEmphasized))
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(style.glow(for: colorScheme))
                    .frame(width: isEmphasized ? 180 : 120, height: isEmphasized ? 180 : 120)
                    .blur(radius: isEmphasized ? 18 : 14)
                    .offset(x: -30, y: -36)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius - 4, style: .continuous)
                    .fill(BrieflyTheme.Colors.cardHighlight(colorScheme))
                    .frame(width: isEmphasized ? 140 : 92, height: isEmphasized ? 140 : 92)
                    .blur(radius: isEmphasized ? 34 : 28)
                    .offset(x: 42, y: 54)
                    .opacity(colorScheme == .dark ? 0.16 : 0.34)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                    .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
            )
            .shadow(
                color: style.glow(for: colorScheme),
                radius: isEmphasized ? 22 : 14,
                x: 0,
                y: isEmphasized ? 16 : 10
            )
            .shadow(
                color: BrieflyTheme.Colors.shadowSoft(colorScheme),
                radius: isEmphasized ? 18 : 10,
                x: 0,
                y: isEmphasized ? 12 : 6
            )
    }

    private func chip(title: String, icon: String, fillColor: Color, foregroundColor: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(fillColor)
            )
    }
}
