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

    private var headerProgressText: String? {
        guard !viewModel.cards.isEmpty else { return nil }
        if viewModel.isSectionComplete { return "Section complete" }
        return "Card \(viewModel.currentIndex + 1) of \(viewModel.cards.count)"
    }

    private var sectionProgressText: String {
        guard let index = viewModel.topic.sections.firstIndex(where: { $0.id == viewModel.section.id }) else {
            return "Section"
        }
        return "Section \(index + 1) of \(viewModel.topic.sections.count)"
    }

    private var nextSection: TopicSection? {
        guard let currentIndex = viewModel.topic.sections.firstIndex(where: { $0.id == viewModel.section.id }) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        return viewModel.topic.sections.indices.contains(nextIndex) ? viewModel.topic.sections[nextIndex] : nil
    }

    private var currentCardNumber: Int {
        guard !viewModel.cards.isEmpty else { return 0 }
        return min(viewModel.currentIndex + 1, viewModel.cards.count)
    }

    private var remainingCards: Int {
        max(viewModel.cards.count - currentCardNumber, 0)
    }

    private var progressPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 18) {
            headerView

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
                .id(card.id)
                .padding(.horizontal, 20)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

                studyStatsView
                    .padding(.horizontal, 20)
            } else {
                completionView
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.currentCard != nil {
                bottomActionTray
            }
        }
        .background(BrieflyTheme.Colors.deckBackgroundGradient(colorScheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(sectionProgressText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(BrieflyTheme.Colors.accentSoft(colorScheme))
                    )

                Spacer()

                if let headerText = headerProgressText {
                    Text(headerText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }

            Text(viewModel.section.title)
                .font(.title2.weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.topic.title)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)

            ProgressView(value: progressFraction)
                .tint(BrieflyTheme.Colors.accent)
                .background(BrieflyTheme.Colors.progressTrack(colorScheme))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrieflyTheme.Colors.deckHeaderGradient(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
    }

    private var completionView: some View {
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
                .padding(.horizontal, 12)

            if let nextSection = nextSection {
                Button("Continue to \(nextSection.title)") {
                    BrieflyHaptics.soft()
                    coordinator.showDeck(for: viewModel.topic, section: nextSection)
                }
                .buttonStyle(BrieflyDeckPrimaryButtonStyle())
            }

            Button("Restart section") {
                BrieflyHaptics.soft()
                viewModel.restart()
            }
            .buttonStyle(BrieflyDeckSecondaryButtonStyle())

            Button("Back to topics") {
                BrieflyHaptics.light()
                coordinator.popToRoot()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 12, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
        .onAppear {
            BrieflyHaptics.success()
        }
    }

    private var bottomActionTray: some View {
        VStack(spacing: 12) {
            if viewModel.isShowingBack {
                HStack(spacing: 12) {
                    Button {
                        viewModel.markReviewAndAdvance()
                    } label: {
                        Text("Review again")
                    }
                    .buttonStyle(BrieflyDeckSecondaryButtonStyle())

                    Button {
                        BrieflyHaptics.soft()
                        viewModel.markKnownAndAdvance()
                    } label: {
                        Text("Got it")
                    }
                    .buttonStyle(BrieflyDeckPrimaryButtonStyle())
                }
            } else {
                Button {
                    BrieflyHaptics.soft()
                    viewModel.reveal()
                } label: {
                    Text("See answer")
                }
                .buttonStyle(BrieflyDeckPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(BrieflyTheme.Colors.deckActionTray(colorScheme).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }

    private var studyStatsView: some View {
        HStack(spacing: 10) {
            studyMetric(title: "Current", value: "\(currentCardNumber)")
            studyMetric(title: "Remaining", value: "\(remainingCards)")
            studyMetric(title: "Progress", value: "\(progressPercent)%")
        }
    }

    private func studyMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
        )
    }
}
