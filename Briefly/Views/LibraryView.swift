import SwiftUI
import os

struct LibraryView: View {
    private static let logger = Logger(subsystem: "dn.Briefly", category: "LibraryView")

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
    @State private var cannedGeneratedReviewDTO: TopicPackDTO?

    private let continueCardWidth: CGFloat = 320
    private let browseCardWidth: CGFloat = 280
    private let sectionHorizontalInset: CGFloat = 16
    private let sectionSpacing: CGFloat = 16

    var body: some View {
        List {
            overviewSection

            if hasActiveFilters {
                activeFiltersRow
            }

            if !viewModel.continueLearningTopics.isEmpty {
                continueLearningSection
            }

            if !viewModel.exploreTopicGroups.isEmpty {
                exploreSection
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
        .listSectionSpacing(sectionSpacing)
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
            ToolbarItem(placement: .principal) {
                compactLibraryHeader
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if ProcessInfo.processInfo.arguments.contains("-uiTestUseCannedGeneratedPack") {
                            cannedGeneratedReviewDTO = Self.uiTestCannedGeneratedPack()
                        } else {
                            showingAIGenerator = true
                        }
                    } label: {
                        Label("Create Topic", systemImage: "plus.circle")
                    }

                    Button {
                        Task { await generateRandomTopic() }
                    } label: {
                        Label("Surprise Me", systemImage: "dice")
                    }
                    .disabled(isGeneratingRandom)
                } label: {
                    toolbarChip(title: "Create", systemImage: "plus")
                }
                .accessibilityLabel("Create topic")

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
                        clearFilters()
                    }
                    .disabled(!hasActiveFilters)

                    Divider()

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Models", systemImage: "gearshape")
                    }
                } label: {
                    toolbarChip(
                        title: "Filter",
                        systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                    )
                }
                .accessibilityLabel("Filter topics")
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
        .sheet(isPresented: Binding(
            get: { cannedGeneratedReviewDTO != nil },
            set: { isPresented in
                if !isPresented {
                    cannedGeneratedReviewDTO = nil
                }
            }
        )) {
            if let dto = cannedGeneratedReviewDTO {
                NavigationStack {
                    GeneratedPackReviewView(
                        viewModel: GeneratedPackReviewViewModel(pack: dto),
                        onSave: { editedDTO in
                            await saveGeneratedReviewDTO(editedDTO)
                        },
                        originalDTO: dto
                    )
                }
            }
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
                    Text("Creating topic…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BrieflyTheme.Colors.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .overlay(
                            Capsule()
                                .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                        )
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 10, x: 0, y: 6)
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
            .listRowInsets(EdgeInsets(top: 6, leading: sectionHorizontalInset, bottom: 6, trailing: sectionHorizontalInset))
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundColor(BrieflyTheme.Colors.accent)

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

            HStack(spacing: 10) {
                Button {
                    showingAIGenerator = true
                } label: {
                    overviewActionButton(
                        title: "Create Topic",
                        systemImage: "plus.circle.fill",
                        style: .primary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await generateRandomTopic() }
                } label: {
                    overviewActionButton(
                        title: "Surprise Me",
                        systemImage: "dice.fill",
                        style: .secondary
                    )
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingRandom)
                .opacity(isGeneratingRandom ? 0.6 : 1)
            }

            HStack(spacing: 12) {
                insightPill(title: "Active", value: "\(viewModel.activeTopics.count)")
                insightPill(title: "Studying", value: "\(viewModel.inProgressTopicCount)")
                insightPill(title: "Completed", value: "\(viewModel.completedTopics.count)")
            }
        }
        .padding(22)
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrieflyTheme.Colors.cardBackground(colorScheme),
                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.42),
                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(BrieflyTheme.Colors.libraryAmbientSecondary(colorScheme))
                        .frame(width: 130, height: 130)
                        .blur(radius: 26)
                        .offset(x: -20, y: -28)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(BrieflyTheme.Colors.libraryAmbientPrimary(colorScheme))
                        .frame(width: 190, height: 190)
                        .blur(radius: 28)
                        .offset(x: 34, y: -44)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
                .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 18, x: 0, y: 12)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: sectionHorizontalInset, bottom: 4, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
    }

    private var activeFiltersRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Filters")
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
        .listRowInsets(EdgeInsets(top: 2, leading: sectionHorizontalInset, bottom: 6, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
    }

    private var continueLearningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Continue",
                subtitle: "Recent and in-progress topics stay front and center."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(viewModel.continueLearningTopics) { topic in
                        libraryTopicButton(topic, variant: .continueLearning)
                            .frame(width: continueCardWidth, height: 220)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .background(sectionShell(accent: BrieflyTheme.Colors.libraryAmbientPrimary(colorScheme)))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: sectionHorizontalInset, bottom: 6, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
    }

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Browse Topics",
                subtitle: "Browse by category instead of scrolling one long list."
            )

            ForEach(viewModel.exploreTopicGroups) { group in
                let style = BrieflyTheme.Colors.topicStyle(for: group.title)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(group.title, systemImage: style.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(BrieflyTheme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(style.ambient(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.10))
                                    .overlay(
                                        Capsule()
                                            .stroke(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.12))
                                    )
                            )

                        Spacer()

                        Text("\(group.topics.count) topic\(group.topics.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(group.topics) { topic in
                                libraryTopicButton(topic, variant: .standard)
                                    .frame(width: browseCardWidth, height: 220)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(16)
                .background(sectionShell(accent: style.ambient(for: colorScheme)))
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: sectionHorizontalInset, bottom: 8, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(BrieflyTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 1)
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
        let isEmpty = value == "0"

        return VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary.opacity(isEmpty ? 0.72 : 1))

            Text(title)
                .font(.caption)
                .foregroundColor(BrieflyTheme.Colors.textSecondary.opacity(isEmpty ? 0.82 : 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrieflyTheme.Colors.elevatedBackground(colorScheme),
                            BrieflyTheme.Colors.accentSoft(colorScheme).opacity(isEmpty ? (colorScheme == .dark ? 0.08 : 0.10) : (colorScheme == .dark ? 0.14 : 0.18))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
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
            .frame(
                width: cardWidth(for: variant),
                height: cardHeight(for: variant),
                alignment: .topLeading
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
        .contextMenu {
            Button {
                withAnimation {
                    viewModel.toggleCompleted(topic)
                }
            } label: {
                Label(viewModel.isCompleted(topic) ? "Mark Incomplete" : "Mark Complete", systemImage: "checkmark.seal")
            }

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
                Label("Delete Topic", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("library.topic.card")
    }

    private func cardWidth(for variant: TopicCardView.Variant) -> CGFloat {
        switch variant {
        case .standard:
            return browseCardWidth
        case .continueLearning:
            return continueCardWidth
        case .featured:
            return continueCardWidth
        }
    }

    private func cardHeight(for variant: TopicCardView.Variant) -> CGFloat {
        switch variant {
        case .featured:
            return 250
        case .standard, .continueLearning:
            return 220
        }
    }

    private func toolbarChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(BrieflyTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.74),
                                BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                    )
            )
            .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 6, x: 0, y: 3)
    }

    private func overviewActionButton(title: String, systemImage: String, style: OverviewActionStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundColor(style == .primary ? .white : BrieflyTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    style == .primary
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                BrieflyTheme.Colors.accent,
                                BrieflyTheme.Colors.accent.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.62),
                                BrieflyTheme.Colors.accentSoft(colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            style == .primary
                            ? Color.white.opacity(0.10)
                            : BrieflyTheme.Colors.cardStroke(colorScheme)
                        )
                )
        )
        .shadow(
            color: style == .primary ? BrieflyTheme.Colors.accent.opacity(0.18) : BrieflyTheme.Colors.shadowSoft(colorScheme),
            radius: style == .primary ? 10 : 6,
            x: 0,
            y: style == .primary ? 6 : 3
        )
    }

    private func sectionShell(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrieflyTheme.Colors.cardBackground(colorScheme).opacity(colorScheme == .dark ? 0.94 : 0.96),
                        accent.opacity(colorScheme == .dark ? 0.08 : 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(accent.opacity(colorScheme == .dark ? 0.10 : 0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 22)
                    .offset(x: 20, y: -20)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
            )
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
                Self.logger.error(
                    "Surprise Me surfaced error: classification=\(surpriseMeErrorClassification(for: error), privacy: .public) message=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func surpriseMeErrorClassification(for error: Error) -> String {
        if let serviceError = error as? AIContentService.ServiceError {
            switch serviceError {
            case .emptyResponse:
                return "empty_response"
            case .invalidJSON:
                return "decode_invalid_json"
            case .dtoDecodingFailed:
                return "decode_dto_failed"
            case .validationFailed:
                return "validation_failed"
            case .jobTransportUnavailable:
                return "job_transport_unavailable"
            }
        }
        if let clientError = error as? BrieflyBackendClient.ClientError {
            switch clientError {
            case .badResponse:
                return "backend_http_failure"
            case .invalidResponse:
                return "backend_invalid_envelope"
            case .requestTimedOut:
                return "backend_timeout"
            case .transport:
                return "backend_transport_failure"
            case .jobNotFound:
                return "job_not_found"
            case .jobNotReady:
                return "job_not_ready"
            case .jobFailed:
                return "job_failed"
            }
        }
        if error is ContentRepository.RepositoryError {
            return "persistence_failure"
        }
        return "unknown"
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

    private func saveGeneratedReviewDTO(_ dto: TopicPackDTO) async -> Bool {
        do {
            guard try await ContentRepository.shared.appendOrReplaceUserPack(dto) != nil else {
                libraryError = "Edited content could not be parsed."
                return false
            }
            cannedGeneratedReviewDTO = nil
            return true
        } catch {
            libraryError = error.localizedDescription
            return false
        }
    }

    private static func uiTestCannedGeneratedPack() -> TopicPackDTO {
        TopicPackDTO(
            id: "ui_test_generated_pack",
            title: "UI Canned Generated Pack",
            subtitle: "Canned generated topic for UI smoke tests.",
            category: "Generated",
            difficulty: Difficulty.beginner.rawValue,
            language: "en",
            description: "Generated locally for deterministic review and save coverage.",
            author: nil,
            version: "1",
            sections: [
                TopicSectionDTO(
                    id: "ui_test_generated_section_1",
                    title: "Canned Review Section",
                    cards: [
                        CardDTO(
                            id: "ui_test_generated_card_1",
                            front: "What does this smoke test prove?",
                            back: "A generated pack can be reviewed and saved without network access.",
                            source: nil,
                            tags: nil
                        )
                    ]
                )
            ]
        )
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
            Text("Create your first topic and start building your library.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button("Create Topic") {
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
            Image(systemName: "rectangle.stack.fill.badge.plus")
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
                .overlay(
                    Capsule()
                        .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
                )
        )
        .opacity(libraryCompactHeaderVisible ? 1 : 0)
        .scaleEffect(libraryCompactHeaderVisible ? 1 : 0.98)
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

private enum OverviewActionStyle {
    case primary
    case secondary
}
