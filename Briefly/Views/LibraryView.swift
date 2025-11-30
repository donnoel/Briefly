import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showingAIGenerator = false
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: BrieflyTheme.Layout.cardSpacing) {
                ForEach(viewModel.topics) { topic in
                    Button {
                        coordinator.showTopic(topic)
                    } label: {
                        TopicCardView(
                            topic: topic,
                            progress: viewModel.progress(for: topic)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
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
                Button {
                    showingAIGenerator = true
                } label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("Generate with AI")
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            AIGenerationSheet(isPresented: $showingAIGenerator) { newTopic in
                viewModel.insert(newTopic)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
        }
    }
}
