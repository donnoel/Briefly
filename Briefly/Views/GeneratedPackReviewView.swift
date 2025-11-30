import SwiftUI

struct GeneratedPackReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GeneratedPackReviewViewModel
    let onSave: (TopicPackDTO) -> Void
    let originalDTO: TopicPackDTO

    var body: some View {
        Form {
            Section("Topic") {
                TextField("Title", text: $viewModel.title)
                TextField("Subtitle", text: $viewModel.subtitle)
                TextField("Category", text: $viewModel.category)
                Picker("Difficulty", selection: $viewModel.difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue).tag(difficulty)
                    }
                }
                Stepper(value: $viewModel.estimatedMinutes, in: 5...120, step: 5) {
                    Text("Estimated minutes: \(viewModel.estimatedMinutes)")
                }
                TextField("Description", text: $viewModel.description, axis: .vertical)
                    .lineLimit(1...3)
            }

            ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                Section(section.title.isEmpty ? "Section \(index + 1)" : section.title) {
                    TextField("Section title", text: binding(forSectionTitleAt: index))

                    ForEach(Array(section.cards.enumerated()), id: \.element.id) { cardIndex, card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Card \(cardIndex + 1)").font(.caption).foregroundColor(.secondary)
                            TextField("Front", text: binding(forCardFrontAt: cardIndex, section: index), axis: .vertical)
                                .lineLimit(1...3)
                            TextField("Back", text: binding(forCardBackAt: cardIndex, section: index), axis: .vertical)
                                .lineLimit(1...4)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Review & Edit")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(viewModel.toDTO(original: originalDTO))
                    dismiss()
                }
            }
        }
    }

    private func binding(forSectionTitleAt index: Int) -> Binding<String> {
        Binding(
            get: { viewModel.sections[index].title },
            set: { viewModel.sections[index].title = $0 }
        )
    }

    private func binding(forCardFrontAt cardIndex: Int, section: Int) -> Binding<String> {
        Binding(
            get: { viewModel.sections[section].cards[cardIndex].front },
            set: { viewModel.sections[section].cards[cardIndex].front = $0 }
        )
    }

    private func binding(forCardBackAt cardIndex: Int, section: Int) -> Binding<String> {
        Binding(
            get: { viewModel.sections[section].cards[cardIndex].back },
            set: { viewModel.sections[section].cards[cardIndex].back = $0 }
        )
    }
}
