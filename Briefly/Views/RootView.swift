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
                    DeckView(
                        viewModel: DeckSessionViewModel(
                            topic: topic,
                            section: section,
                            progressStore: ProgressStore.shared,
                            statusStore: TopicStatusStore.shared
                        )
                    )
                }
            }
        }
    }
}
