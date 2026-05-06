import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Namespace private var topicTransition
    @StateObject private var contentRepository = ContentRepository.shared
    @StateObject private var libraryViewModel = LibraryViewModel(
        contentRepository: ContentRepository.shared,
        progressStore: ProgressStore.shared
    )

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LibraryView(viewModel: libraryViewModel, topicTransition: topicTransition)
            .navigationDestination(for: AppCoordinator.Route.self) { route in
                switch route {
                case .topic(let topicID):
                    if let topic = contentRepository.topics.first(where: { $0.id == topicID }) {
                        TopicDetailView(
                            viewModel: TopicDetailViewModel(
                                topic: topic,
                                progressStore: ProgressStore.shared
                            ),
                            topicTransition: topicTransition
                        )
                    } else {
                        MissingRouteContentView(message: "This topic is no longer available.")
                    }
                case .deck(let topicID, let sectionID):
                    if let topic = contentRepository.topics.first(where: { $0.id == topicID }),
                       let section = topic.sections.first(where: { $0.id == sectionID }) {
                        DeckRouteView(topic: topic, section: section)
                    } else {
                        MissingRouteContentView(message: "This section is no longer available.")
                    }
                }
            }
        }
    }
}

private struct DeckRouteView: View {
    @StateObject private var viewModel: DeckSessionViewModel

    init(topic: TopicPack, section: TopicSection) {
        _viewModel = StateObject(
            wrappedValue: DeckSessionViewModel(
                topic: topic,
                section: section,
                progressStore: ProgressStore.shared,
                statusStore: TopicStatusStore.shared
            )
        )
    }

    var body: some View {
        DeckView(viewModel: viewModel)
    }
}

private struct MissingRouteContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Back to Library") {
                coordinator.popToRoot()
            }
        }
        .padding()
        .navigationTitle("Unavailable")
    }
}
