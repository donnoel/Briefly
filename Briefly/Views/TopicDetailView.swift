import SwiftUI

struct TopicDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject var viewModel: TopicDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Hero summary card
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.topic.title)
                        .font(.title2.bold())
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)

                    Text(viewModel.topic.subtitle)
                        .font(.subheadline)
                        .foregroundColor(BrieflyTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Label(viewModel.topic.category, systemImage: "book.closed")
                            .font(.caption)

                        Label(viewModel.topic.difficulty.rawValue,
                              systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)

                        Label("\(viewModel.topic.estimatedMinutes) min",
                              systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.progressText())
                            .font(.caption)
                            .foregroundColor(BrieflyTheme.Colors.textSecondary)

                        ProgressView(value: viewModel.progressFraction())
                            .progressViewStyle(.linear)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: BrieflyTheme.Layout.cardCornerRadius, style: .continuous)
                        .fill(BrieflyTheme.Colors.cardBackground)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
                )
                .padding(.horizontal, 16)

                // Sections header
                if !viewModel.sections.isEmpty {
                    Text("Sections")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }

                // Section cards
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sections) { section in
                        Button {
                            coordinator.showDeck(for: viewModel.topic, section: section)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundColor(BrieflyTheme.Colors.textPrimary)

                                    Text("\(section.cards.count) cards")
                                        .font(.caption)
                                        .foregroundColor(BrieflyTheme.Colors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: BrieflyTheme.Layout.cardCornerRadius,
                                    style: .continuous
                                )
                                .fill(BrieflyTheme.Colors.cardBackground)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
        .background(BrieflyTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(viewModel.topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
