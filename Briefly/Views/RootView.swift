import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Namespace private var topicTransition
    @StateObject private var libraryViewModel = LibraryViewModel(
        contentRepository: ContentRepository.shared,
        progressStore: ProgressStore.shared
    )

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LibraryView(viewModel: libraryViewModel, topicTransition: topicTransition)
            .navigationDestination(for: AppCoordinator.Route.self) { route in
                switch route {
                case .topic(let topic):
                    TopicDetailView(
                        viewModel: TopicDetailViewModel(
                            topic: topic,
                            progressStore: ProgressStore.shared
                        ),
                        topicTransition: topicTransition
                    )
                case .deck(let topic, let section):
                    DeckRouteView(topic: topic, section: section)
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
