import SwiftUI

struct DeckView: View {
    @ObservedObject var viewModel: DeckSessionViewModel

    private var progressFraction: Double {
        guard !viewModel.cards.isEmpty else { return 0 }
        return Double(viewModel.currentIndex + 1) / Double(viewModel.cards.count)
    }

    var body: some View {
        VStack(spacing: 20) {

            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.topic.title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(viewModel.section.title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)
                    Text("Card \(viewModel.currentIndex + 1) of \(viewModel.cards.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 8)

            // Card area
            if let card = viewModel.currentCard {
                CardView(
                    card: card,
                    isShowingBack: viewModel.isShowingBack,
                    revealAction: { viewModel.reveal() }
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 12) {
                    Text("Section complete")
                        .font(.title3.bold())
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)

                    Button("Restart section") {
                        viewModel.restart()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Bottom actions
            if viewModel.currentCard != nil {
                if viewModel.isShowingBack {
                    HStack(spacing: 16) {
                        Button {
                            viewModel.markReviewAndAdvance()
                        } label: {
                            Text("Review again")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.markKnownAndAdvance()
                        } label: {
                            Text("Got it")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                } else {
                    Button {
                        viewModel.reveal()
                    } label: {
                        Text("See answer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }

        }
        .background(BrieflyTheme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
