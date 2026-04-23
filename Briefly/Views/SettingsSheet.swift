import SwiftUI

struct SettingsSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Generation") {
                    Label("No API key needed", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Briefly now uses a managed backend for AI topic generation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}
