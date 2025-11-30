import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LibraryView(
                viewModel: LibraryViewModel(
                    contentRepository: ContentRepository.shared,
                    progressStore: ProgressStore.shared
                )
            )
            .navigationTitle("Briefly")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppCoordinator.Route.self) { route in
                switch route {
                case .topic(let topic):
                    TopicDetailView(
                        viewModel: TopicDetailViewModel(
                            topic: topic,
                            progressStore: ProgressStore.shared
                        )
                    )
                case .deck(let topic, let section):
                    DeckView(
                        viewModel: DeckSessionViewModel(
                            topic: topic,
                            section: section,
                            progressStore: ProgressStore.shared
                        )
                    )
                }
            }
        }
    }
}
