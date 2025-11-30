import Foundation

/// Simple UserDefaults-backed store for the OpenAI API key.
final class APIKeyStore {
    static let shared = APIKeyStore()

    private let storageKey = "OpenAIAPIKey"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var apiKey: String? {
        get { defaults.string(forKey: storageKey) }
        set { defaults.setValue(newValue, forKey: storageKey) }
    }
}
