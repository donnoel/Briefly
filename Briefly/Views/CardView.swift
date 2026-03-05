import SwiftUI

struct CardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: Card
    let isShowingBack: Bool
    let revealAction: () -> Void

    private let cardHeight: CGFloat = 320

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    isShowingBack
                    ? BrieflyTheme.Colors.cardGradientBack(colorScheme)
                    : BrieflyTheme.Colors.cardGradientFront(colorScheme)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrieflyTheme.Colors.cardHighlight(colorScheme), lineWidth: 1.5)
                .blur(radius: 0.2)
                .padding(1)

            VStack(alignment: .leading, spacing: 16) {
                Text("Question")
                    .font(.caption.weight(.bold))
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)

                ScrollView(.vertical, showsIndicators: false) {
                    Text(card.front)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .opacity(isShowingBack ? 0 : 1)
            .accessibilityHidden(isShowingBack)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)

            VStack(alignment: .leading, spacing: 16) {
                Text("Answer")
                    .font(.caption.weight(.bold))
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)

                ScrollView(.vertical, showsIndicators: false) {
                    Text(card.back)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .opacity(isShowingBack ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .accessibilityHidden(!isShowingBack)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)

            if !isShowingBack {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Label("Tap to reveal", systemImage: "hand.tap")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(BrieflyTheme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.88))
                            )
                    }
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .compositingGroup()
        .rotation3DEffect(
            .degrees(isShowingBack ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.75
        )
        .shadow(
            color: BrieflyTheme.Colors.shadowSoft(colorScheme),
            radius: 16,
            x: 0,
            y: 10
        )
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if !isShowingBack {
                revealAction()
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: isShowingBack)
    }
}
