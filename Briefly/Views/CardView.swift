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

            VStack(alignment: .leading, spacing: 14) {
                Text(isShowingBack ? "Answer" : "Question")
                    .font(.caption.bold())
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)

                Text(isShowingBack ? card.back : card.front)
                    .font(.title3) // main learning content
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if !isShowingBack {
                    Button {
                        revealAction()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.footnote)
                            Text("Tap to see answer")
                                .font(.footnote)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 340)
        .animation(.easeInOut(duration: 0.18), value: isShowingBack)
    }
}
