import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: LibraryViewModel
    let topicTransition: Namespace.ID
    @State private var showingAIGenerator = false
    @State private var showingSettings = false
    @State private var isGeneratingRandom = false
    @State private var randomError: String?
    @State private var libraryError: String?
    @State private var libraryCompactHeaderVisible = false

    var body: some View {
        List {
            overviewSection

            if hasActiveFilters {
                activeFiltersRow
            }

            if !viewModel.continueLearningTopics.isEmpty {
                continueLearningSection
            }

            if let featuredTopic = viewModel.featuredTopic {
                featuredSection(topic: featuredTopic)
            }

            if !viewModel.exploreTopicGroups.isEmpty {
                exploreSection
            }

            if !viewModel.activeTopics.isEmpty {
                Section {
                    ForEach(viewModel.activeTopics) { topic in
                        topicRow(topic)
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveActiveTopics(from: indices, to: newOffset)
                    }
                } header: {
                    listSectionHeader(
                        title: "Your Order",
                        subtitle: "All active topics remain available here, and you can still reorder them."
                    )
                }
            }

            if !viewModel.completedTopics.isEmpty {
                Section {
                    ForEach(viewModel.completedTopics) { topic in
                        topicRow(topic)
                    }
                } header: {
                    listSectionHeader(
                        title: "Completed",
                        subtitle: "Finished topics stay handy for refreshers and review."
                    )
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(18)
        .coordinateSpace(name: "libraryScroll")
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.25), value: viewModel.activeTopics.count)
        .animation(.easeInOut(duration: 0.25), value: viewModel.completedTopics.count)
        .background(libraryBackground)
        .onPreferenceChange(LibraryOverviewOffsetKey.self) { minY in
            let shouldShowCompactHeader = minY < -72
            if shouldShowCompactHeader != libraryCompactHeaderVisible {
                libraryCompactHeaderVisible = shouldShowCompactHeader
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(libraryCompactHeaderVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .principal) {
                compactLibraryHeader
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await generateRandomTopic() }
                    } label: {
                        Label("Surprise me", systemImage: "sparkles.tv")
                    }
                    .disabled(isGeneratingRandom)

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
                        clearFilters()
                    }
                    .disabled(!hasActiveFilters)
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filters")

                Button {
                    showingAIGenerator = true
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .accessibilityLabel("Generate with AI")
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search topics"
        )
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
            if viewModel.hasCompletedInitialLoad && !hasAnyTopics {
                emptyState
            } else if viewModel.hasCompletedInitialLoad && hasActiveFilters && !hasVisibleTopics {
                noResultsState
            }
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: TopicPack) -> some View {
        libraryTopicButton(topic, variant: .standard)
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
                Task {
                    do {
                        try await viewModel.delete(topic)
                    } catch {
                        await MainActor.run {
                            libraryError = error.localizedDescription
                        }
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resume your momentum")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)

                    Text(hasAnyTopics
                         ? "Continue where you left off, then explore a fresh topic when you're ready."
                         : "Build your first topic pack and turn the library into a place worth returning to.")
                        .font(.subheadline)
                        .foregroundColor(BrieflyTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                if hasAnyTopics {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    BrieflyTheme.Colors.accent,
                                    BrieflyTheme.Colors.accentSecondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.92),
                                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.30 : 0.34)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            }

            HStack(spacing: 12) {
                insightPill(title: "Active", value: "\(viewModel.activeTopics.count)")
                insightPill(title: "In Progress", value: "\(viewModel.inProgressTopicCount)")
                insightPill(title: "Completed", value: "\(viewModel.completedTopics.count)")
            }
        }
        .padding(20)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: LibraryOverviewOffsetKey.self,
                        value: geometry.frame(in: .named("libraryScroll")).minY
                    )
            }
        )
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrieflyTheme.Colors.cardBackground(colorScheme),
                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.46 : 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(BrieflyTheme.Colors.libraryAmbientPrimary(colorScheme))
                        .frame(width: 140, height: 140)
                        .blur(radius: 18)
                        .offset(x: 26, y: -30)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 14, x: 0, y: 10)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var activeFiltersRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtered Results")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        chip(title: "Search: \(viewModel.searchText)") {
                            viewModel.searchText = ""
                        }
                    }
                    if let category = viewModel.selectedCategory {
                        chip(title: "Category: \(category)") {
                            viewModel.selectedCategory = nil
                        }
                    }
                    if let difficulty = viewModel.selectedDifficulty {
                        chip(title: "Difficulty: \(difficulty.rawValue)") {
                            viewModel.selectedDifficulty = nil
                        }
                    }
                    Button("Clear all") {
                        clearFilters()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.vertical, 4)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var continueLearningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Continue Learning",
                subtitle: "Recent and in-progress topics stay front and center."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.continueLearningTopics) { topic in
                        libraryTopicButton(topic, variant: .continueLearning)
                            .frame(width: 320)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 3, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func featuredSection(topic: TopicPack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Featured",
                subtitle: viewModel.progress(for: topic) > 0
                    ? "A premium shortcut back into your most relevant topic."
                    : "A simple editorial pick based on your current library order."
            )

            libraryTopicButton(topic, variant: .featured)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 3, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Explore Topics",
                subtitle: "Browse by category instead of scrolling one long list."
            )

            ForEach(viewModel.exploreTopicGroups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        let style = BrieflyTheme.Colors.topicStyle(for: group.title)

                        Label(group.title, systemImage: style.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(BrieflyTheme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(style.ambient(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.16))
                                    )
                            )

                        Spacer()

                        Text("\(group.topics.count) topic\(group.topics.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(group.topics) { topic in
                                libraryTopicButton(topic, variant: .standard)
                                    .frame(width: 280)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 5, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(BrieflyTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func listSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)

            Text(subtitle)
                .font(.footnote)
                .foregroundColor(BrieflyTheme.Colors.textSecondary)
        }
        .textCase(nil)
    }

    private func insightPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(BrieflyTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrieflyTheme.Colors.elevatedBackground(colorScheme),
                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    @ViewBuilder
    private func libraryTopicButton(_ topic: TopicPack, variant: TopicCardView.Variant) -> some View {
        Button {
            openTopic(topic)
        } label: {
            TopicCardView(
                topic: topic,
                progress: viewModel.progress(for: topic),
                variant: variant
            )
            .matchedTransitionSource(id: topic.id, in: topicTransition)
            .overlay(alignment: .topTrailing) {
                if viewModel.isCompleted(topic) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(8)
                }
            }
        }
        .buttonStyle(InteractiveCardButtonStyle())
        .accessibilityIdentifier("library.topic.card")
    }

    private func generateRandomTopic() async {
        guard !isGeneratingRandom else { return }
        isGeneratingRandom = true
        randomError = nil
        defer { isGeneratingRandom = false }

        do {
            if let topic = try await viewModel.generateRandomTopic(targetSections: 5, cardsPerSection: 10) {
                await MainActor.run {
                    openTopic(topic)
                }
            }
        } catch {
            await MainActor.run {
                randomError = error.localizedDescription
            }
        }
    }

    private var hasVisibleTopics: Bool {
        !viewModel.activeTopics.isEmpty || !viewModel.completedTopics.isEmpty
    }

    private var hasAnyTopics: Bool {
        !viewModel.topics.isEmpty
    }

    private var hasActiveFilters: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.selectedCategory != nil
            || viewModel.selectedDifficulty != nil
    }

    private func clearFilters() {
        viewModel.selectedCategory = nil
        viewModel.selectedDifficulty = nil
        viewModel.searchText = ""
    }

    private func openTopic(_ topic: TopicPack) {
        viewModel.recordTopicOpened(topic)
        coordinator.showTopic(topic)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(BrieflyTheme.Colors.accent)
            Text("No topics yet")
                .font(.headline)
            Text("Generate a new topic with AI.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button("Generate with AI") {
                    showingAIGenerator = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -60)
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundColor(BrieflyTheme.Colors.accent)
            Text("No matching topics")
                .font(.headline)
            Text("Try removing one or more filters, or clear search.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            Button("Clear filters") {
                clearFilters()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -60)
    }

    private func chip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .lineLimit(1)
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

    private var libraryBackground: some View {
        ZStack {
            BrieflyTheme.Colors.background(colorScheme)

            RadialGradient(
                colors: [
                    BrieflyTheme.Colors.libraryAmbientPrimary(colorScheme),
                    .clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 420
            )
            .offset(x: -36, y: -76)

            RadialGradient(
                colors: [
                    BrieflyTheme.Colors.libraryAmbientSecondary(colorScheme),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 340
            )
            .offset(x: 48, y: 120)

            RadialGradient(
                colors: [
                    BrieflyTheme.Colors.libraryAmbientTertiary(colorScheme),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .offset(x: -72, y: 220)

            LinearGradient(
                colors: [
                    BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.06 : 0.08),
                    Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    BrieflyTheme.Colors.libraryAmbientSecondary(colorScheme).opacity(colorScheme == .dark ? 0.06 : 0.05),
                    BrieflyTheme.Colors.libraryAmbientPrimary(colorScheme).opacity(colorScheme == .dark ? 0.05 : 0.04)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var compactLibraryHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Library")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)

                Text(hasAnyTopics ? "\(viewModel.activeTopics.count) active topics" : "Browse your topics")
                    .font(.caption2)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .opacity(libraryCompactHeaderVisible ? 1 : 0)
        .scaleEffect(libraryCompactHeaderVisible ? 1 : 0.96)
        .animation(.easeInOut(duration: 0.2), value: libraryCompactHeaderVisible)
        .accessibilityHidden(!libraryCompactHeaderVisible)
    }
}

private struct LibraryOverviewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
