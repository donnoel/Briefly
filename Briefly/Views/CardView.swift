import SwiftUI

struct CardView: View {
    let card: Card
    let isShowingBack: Bool
    let revealAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.15),
                            Color.purple.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                Text(isShowingBack ? "Answer" : "Question")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(isShowingBack ? card.back : card.front)
                    .font(.title3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if !isShowingBack {
                    Button {
                        revealAction()
                    } label: {
                        Text("Tap to see answer")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320)
        .animation(.easeInOut(duration: 0.2), value: isShowingBack)
    }
}
