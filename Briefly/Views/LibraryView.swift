import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showingAIGenerator = false
    @State private var showingSettings = false

    var body: some View {
        List {
            if !viewModel.activeTopics.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeTopics) { topic in
                        topicRow(topic)
                    }
                }
            }

            if !viewModel.completedTopics.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.completedTopics) { topic in
                        topicRow(topic)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { viewModel.refresh() }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search topics")
        .background(BrieflyTheme.Colors.background(colorScheme).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        if !viewModel.availableCategories.isEmpty {
                            Picker("Category", selection: $viewModel.selectedCategory) {
                                Text("All categories").tag(String?.none)
                                ForEach(viewModel.availableCategories, id: \.self) { category in
                                    Text(category).tag(String?.some(category))
                                }
                            }
                        }

                        Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                            Text("All difficulties").tag(Difficulty?.none)
                            ForEach(Difficulty.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(Difficulty?.some(level))
                            }
                        }

                        Button("Clear filters") {
                            viewModel.selectedCategory = nil
                            viewModel.selectedDifficulty = nil
                            viewModel.searchText = ""
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")

                    Button {
                        showingAIGenerator = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("Generate with AI")
                }
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            AIGenerationSheet(isPresented: $showingAIGenerator) { _ in }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: TopicPack) -> some View {
        Button {
            coordinator.showTopic(topic)
        } label: {
            TopicCardView(
                topic: topic,
                progress: viewModel.progress(for: topic)
            )
            .overlay(alignment: .topTrailing) {
                if viewModel.isCompleted(topic) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(BrieflyTheme.Colors.background(colorScheme))
        .swipeActions(edge: .leading) {
            Button {
                viewModel.toggleCompleted(topic)
            } label: {
                Label(viewModel.isCompleted(topic) ? "Mark Incomplete" : "Mark Complete", systemImage: "checkmark.seal")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(topic)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
