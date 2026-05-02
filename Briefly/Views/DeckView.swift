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

    private var advanceButtonTitle: String {
        guard !viewModel.cards.isEmpty else { return "Next" }
        return viewModel.currentIndex >= viewModel.cards.count - 1 ? "Finish section" : "Next"
    }

    var body: some View {
        VStack(spacing: 18) {
            headerView

            if let card = viewModel.currentCard {
                questionPanel(card: card)
                    .id(card.id)
                    .padding(.horizontal, 20)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                quizOptionsView
                    .padding(.horizontal, 20)

                if viewModel.hasSubmittedCurrentQuestion {
                    answerFeedbackPanel
                        .padding(.horizontal, 20)
                }

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

            Text("You answered \(viewModel.correctAnswerCount) out of \(viewModel.totalQuestionCount) correctly with \(viewModel.scorePercent)% accuracy.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Text(completionPerformanceLine)
                .font(.subheadline.weight(.medium))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)
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
            Button {
                BrieflyHaptics.soft()
                viewModel.advanceAfterSubmission()
            } label: {
                Text(advanceButtonTitle)
            }
            .buttonStyle(BrieflyDeckPrimaryButtonStyle())
            .disabled(!viewModel.hasSubmittedCurrentQuestion)
            .opacity(viewModel.hasSubmittedCurrentQuestion ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(BrieflyTheme.Colors.deckActionTray(colorScheme).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }

    private func questionPanel(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question")
                .font(.caption.weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(BrieflyTheme.Colors.accentSoft(colorScheme))
                )

            Text(card.front)
                .font(.title3.weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.hasSubmittedCurrentQuestion {
                Text("Choose the best answer.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 10, x: 0, y: 6)
        )
    }

    private var answerFeedbackPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.wasSelectedAnswerCorrect ? "Correct" : "Not quite")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(viewModel.wasSelectedAnswerCorrect ? .green : .red)

            if let correctAnswer = viewModel.currentAnswerOptions.first(where: \.isCorrect)?.text {
                Text("Correct answer: \(correctAnswer)")
                    .font(.footnote)
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
        )
    }

    private var quizOptionsView: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.currentAnswerOptions) { option in
                Button {
                    guard !viewModel.hasSubmittedCurrentQuestion else { return }
                    viewModel.submitAnswer(optionID: option.id)
                    if option.isCorrect {
                        BrieflyHaptics.success()
                    } else {
                        BrieflyHaptics.light()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(option.text)
                            .font(.body.weight(.semibold))
                            .foregroundColor(BrieflyTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.hasSubmittedCurrentQuestion {
                            if option.isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green.opacity(0.85))
                            } else if viewModel.selectedAnswerID == option.id {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.85))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(answerBackground(for: option))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.hasSubmittedCurrentQuestion)
                .accessibilityHint(viewModel.hasSubmittedCurrentQuestion ? "Answer locked for this card" : "Tap to submit answer")
            }
        }
    }

    private func answerBackground(for option: DeckSessionViewModel.QuizOption) -> some View {
        let strokeColor: Color
        let fillColor: Color

        if viewModel.hasSubmittedCurrentQuestion {
            if option.isCorrect {
                strokeColor = Color.green.opacity(0.55)
                fillColor = Color.green.opacity(colorScheme == .dark ? 0.18 : 0.1)
            } else if viewModel.selectedAnswerID == option.id {
                strokeColor = Color.red.opacity(0.55)
                fillColor = Color.red.opacity(colorScheme == .dark ? 0.18 : 0.1)
            } else {
                strokeColor = BrieflyTheme.Colors.cardStroke(colorScheme)
                fillColor = BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.88)
            }
        } else if viewModel.selectedAnswerID == option.id {
            strokeColor = BrieflyTheme.Colors.accent
            fillColor = BrieflyTheme.Colors.accentSoft(colorScheme)
        } else {
            strokeColor = BrieflyTheme.Colors.cardStroke(colorScheme)
            fillColor = BrieflyTheme.Colors.cardBackground(colorScheme).opacity(0.88)
        }

        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    private var studyStatsView: some View {
        HStack(spacing: 10) {
            studyMetric(title: "Question", value: "\(currentCardNumber)")
            studyMetric(title: "Correct", value: "\(viewModel.correctAnswerCount)")
            studyMetric(title: "Accuracy", value: "\(viewModel.scorePercent)%")
        }
    }

    private var completionPerformanceLine: String {
        switch viewModel.scorePercent {
        case 90...100:
            return "Strong recall. You are ready to move on."
        case 70...89:
            return "Good progress. Another pass will sharpen it."
        default:
            return "Nice effort. One more pass will build confidence."
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
