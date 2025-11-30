import SwiftUI

struct TopicDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject var viewModel: TopicDetailViewModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.topic.title)
                        .font(.title2.bold())
                    Text(viewModel.topic.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Label(viewModel.topic.category, systemImage: "book")
                            .font(.caption)
                        Label(viewModel.topic.difficulty.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                        Label("\(viewModel.topic.estimatedMinutes) min", systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.progressText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ProgressView(value: viewModel.progressFraction())
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Sections") {
                ForEach(viewModel.sections) { section in
                    Button {
                        coordinator.showDeck(for: viewModel.topic, section: section)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.headline)
                                Text("\(section.cards.count) cards")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
