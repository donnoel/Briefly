import SwiftUI

struct DeckView: View {
    @ObservedObject var viewModel: DeckSessionViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.section.title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let card = viewModel.currentCard {
                CardView(
                    card: card,
                    isShowingBack: viewModel.isShowingBack,
                    revealAction: { viewModel.reveal() }
                )
                .padding(.horizontal, 24)

                Text("Card \(viewModel.currentIndex + 1) of \(viewModel.cards.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isShowingBack {
                    HStack(spacing: 16) {
                        Button(role: .none) {
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
                } else {
                    Button {
                        viewModel.reveal()
                    } label: {
                        Text("See answer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Section complete")
                        .font(.title3.bold())
                    Button("Restart section") {
                        viewModel.restart()
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle(viewModel.topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
