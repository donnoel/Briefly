import SwiftUI

struct AIGenerationSheet: View {
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var difficulty: Difficulty = .beginner
    @State private var estimatedMinutes: Int = 20
    @State private var language: String = "en"

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("Title or concept", text: $title)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    Stepper(value: $estimatedMinutes, in: 5...90, step: 5) {
                        Text("Estimated minutes: \(estimatedMinutes)")
                    }
                    TextField("Language (e.g., en, es)", text: $language)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        // TODO: Wire to AIContentService and ContentRepository.appendUserPack
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Content will be drafted with OpenAI and can be reviewed before saving.")
                }
            }
            .navigationTitle("New AI Topic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}
