import SwiftUI

struct CardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: Card
    let isShowingBack: Bool
    let revealAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    isShowingBack
                    ? BrieflyTheme.Colors.cardGradientBack(colorScheme)
                    : BrieflyTheme.Colors.cardGradientFront(colorScheme)
                )
                .shadow(
                    color: BrieflyTheme.Colors.shadowSoft(colorScheme),
                    radius: 14,
                    x: 0,
                    y: 10
                )

            VStack(alignment: .leading, spacing: 18) {
                Text(isShowingBack ? "Answer" : "Question")
                    .font(.caption.bold())
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)

                Text(isShowingBack ? card.back : card.front)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
        .animation(.easeInOut(duration: 0.18), value: isShowingBack)
    }
}
