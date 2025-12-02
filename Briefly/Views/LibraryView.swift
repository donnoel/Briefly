import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showingAIGenerator = false
    @State private var showingSettings = false
    @State private var isGeneratingRandom = false
    @State private var randomError: String?
    @State private var libraryError: String?

    var body: some View {
        List {
            if !viewModel.activeTopics.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeTopics) { topic in
                        topicRow(topic)
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveActiveTopics(from: indices, to: newOffset)
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
        .animation(.easeInOut(duration: 0.25), value: viewModel.activeTopics.count)
        .animation(.easeInOut(duration: 0.25), value: viewModel.completedTopics.count)
        .background(
            LinearGradient(
                colors: [
                    BrieflyTheme.Colors.background(colorScheme),
                    BrieflyTheme.Colors.accentSoft(colorScheme).opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .toolbarBackground(.hidden, for: .navigationBar)
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
                    Button {
                        Task { await generateRandomTopic() }
                    } label: {
                        Image(systemName: "sparkles.tv")
                            .symbolEffect(.pulse.byLayer, isActive: isGeneratingRandom)
                    }
                    .disabled(isGeneratingRandom)
                    .accessibilityLabel("Surprise me")

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
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
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
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search topics")
        .sheet(isPresented: $showingAIGenerator) {
            AIGenerationSheet(isPresented: $showingAIGenerator) { _ in }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
        }
        .alert("Generation failed", isPresented: Binding(
            get: { randomError != nil },
            set: { _ in randomError = nil }
        )) {
            Button("OK") { randomError = nil }
        } message: {
            Text(randomError ?? "")
        }
        .alert("Save failed", isPresented: Binding(
            get: { libraryError != nil },
            set: { _ in libraryError = nil }
        )) {
            Button("OK") { libraryError = nil }
        } message: {
            Text(libraryError ?? "")
        }
        .overlay(alignment: .top) {
            if isGeneratingRandom {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Creating a topic for you…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .padding(.top, 8)
            }
        }
        .overlay {
            if !hasTopics {
                emptyState
            }
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(BrieflyTheme.Colors.background(colorScheme))
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
        .swipeActions(edge: .leading) {
            Button {
                withAnimation {
                    viewModel.toggleCompleted(topic)
                }
            } label: {
                Label(viewModel.isCompleted(topic) ? "Mark Incomplete" : "Mark Complete", systemImage: "checkmark.seal")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation {
                    do {
                        try viewModel.delete(topic)
                    } catch {
                        libraryError = error.localizedDescription
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func generateRandomTopic() async {
        guard !isGeneratingRandom else { return }
        isGeneratingRandom = true
        randomError = nil
        defer { isGeneratingRandom = false }

        do {
            if let topic = try await viewModel.generateRandomTopic(targetSections: 3, cardsPerSection: 5) {
                await MainActor.run {
                    coordinator.showTopic(topic)
                }
            }
        } catch {
            await MainActor.run {
                randomError = error.localizedDescription
            }
        }
    }

    private var hasTopics: Bool {
        !viewModel.activeTopics.isEmpty || !viewModel.completedTopics.isEmpty
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(BrieflyTheme.Colors.accent)
            Text("No topics yet")
                .font(.headline)
            Text("Generate a new topic with AI or set your OpenAI key in Settings.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button("Generate with AI") {
                    showingAIGenerator = true
                }
                .buttonStyle(BrieflyPrimaryButtonStyle())
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(BrieflySecondaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(BrieflyTheme.Colors.accentSoft(colorScheme))
                )
                .foregroundColor(BrieflyTheme.Colors.accent)
        }
        .buttonStyle(.plain)
    }
}
