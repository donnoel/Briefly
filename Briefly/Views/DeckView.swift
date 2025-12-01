import SwiftUI

struct DeckView: View {
    @ObservedObject var viewModel: DeckSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var coordinator: AppCoordinator

    private var progressFraction: Double {
        guard !viewModel.cards.isEmpty else { return 0 }
        if viewModel.isSectionComplete { return 1.0 }
        return Double(viewModel.currentIndex + 1) / Double(viewModel.cards.count)
    }

    private var nextSection: TopicSection? {
        guard let currentIndex = viewModel.topic.sections.firstIndex(where: { $0.id == viewModel.section.id }) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        return viewModel.topic.sections.indices.contains(nextIndex) ? viewModel.topic.sections[nextIndex] : nil
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

            // Card or completion
            if let card = viewModel.currentCard {
                CardView(
                    card: card,
                    isShowingBack: viewModel.isShowingBack,
                    revealAction: {
                        if !viewModel.isShowingBack {
                            BrieflyHaptics.soft()
                        }
                        viewModel.reveal()
                    }
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(BrieflyTheme.Colors.accent)

                    Text("Section complete")
                        .font(.title3.bold())
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)

                    Text("You’ve seen every card in this section. Restart or continue to the next section.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let nextSection = nextSection {
                        Button("Continue to \(nextSection.title)") {
                            BrieflyHaptics.soft()
                            coordinator.showDeck(for: viewModel.topic, section: nextSection)
                        }
                        .buttonStyle(BrieflyPrimaryButtonStyle())
                    }

                    Button("Restart section") {
                        BrieflyHaptics.soft()
                        viewModel.restart()
                    }
                    .buttonStyle(BrieflySecondaryButtonStyle())

                    Button("Back to topic") {
                        BrieflyHaptics.light()
                        coordinator.popLast()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .onAppear {
                    BrieflyHaptics.success()
                }
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
                    }
                        .buttonStyle(BrieflySecondaryButtonStyle())

                        Button {
                            BrieflyHaptics.soft()
                            viewModel.markKnownAndAdvance()
                        } label: {
                            Text("Got it")
                        }
                        .buttonStyle(BrieflyPrimaryButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                } else {
                    Button {
                        BrieflyHaptics.soft()
                        viewModel.reveal()
                    } label: {
                        Text("See answer")
                    }
                    .buttonStyle(BrieflyPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }

        }
        .background(BrieflyTheme.Colors.background(colorScheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
