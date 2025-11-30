import SwiftUI

struct TopicCardView: View {
    let topic: TopicPack
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline)
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

                Text(topic.difficulty.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(BrieflyTheme.Colors.accentSoft)
                    )
                    .foregroundColor(BrieflyTheme.Colors.accent)
            }

            // Progress
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(BrieflyTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                .fill(BrieflyTheme.Colors.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius))
    }
}
