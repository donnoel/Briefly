import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showingAIGenerator = false
    @State private var showingSettings = false
    @State private var isGeneratingRandom = false
    @State private var randomError: String?

    var body: some View {
        List {
            if !viewModel.featuredTopics.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.featuredTopics) { topic in
                                Button {
                                    coordinator.showTopic(topic)
                                } label: {
                                    TopicCardView(
                                        topic: topic,
                                        progress: viewModel.progress(for: topic)
                                    )
                                    .frame(width: 280)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Featured")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                }
            }

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
        .refreshable { viewModel.refresh() }
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
        .safeAreaInset(edge: .top, alignment: .center) {
            if !viewModel.availableCategories.isEmpty || !Difficulty.allCases.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if !viewModel.availableCategories.isEmpty {
                            chip(title: viewModel.selectedCategory ?? "All categories") {
                                if viewModel.selectedCategory == nil {
                                    viewModel.selectedCategory = viewModel.availableCategories.first
                                } else {
                                    viewModel.selectedCategory = nil
                                }
                            }
                        }

                        chip(title: viewModel.selectedDifficulty?.rawValue ?? "All levels") {
                            if viewModel.selectedDifficulty == nil {
                                viewModel.selectedDifficulty = Difficulty.allCases.first
                            } else {
                                viewModel.selectedDifficulty = nil
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(.ultraThinMaterial)
            }
        }
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
                    viewModel.delete(topic)
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
