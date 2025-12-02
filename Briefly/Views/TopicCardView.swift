import SwiftUI

struct TopicCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let topic: TopicPack
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)

                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            // Metadata chips
            HStack(spacing: 8) {
                Label(topic.category, systemImage: "book.closed")
                    .font(.caption)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(BrieflyTheme.Colors.accentSoft(colorScheme))
                    )

                Text(topic.difficulty.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(BrieflyTheme.Colors.accentSoft(colorScheme))
                    )
                    .foregroundColor(BrieflyTheme.Colors.accent)
            }

            // Progress
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)

                Text("\(Int(progress * 100))%")
                    .font(.caption)            // tertiary info
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(BrieflyTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.9),
                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme),
                        radius: 10, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius))
    }
}
