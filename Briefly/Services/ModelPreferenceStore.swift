import Foundation

/// Stores preferred OpenAI model in UserDefaults.
final class ModelPreferenceStore {
    static let shared = ModelPreferenceStore()

    private let storageKey = "OpenAIModelPreference"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferredModel: String? {
        get { defaults.string(forKey: storageKey) }
        set { defaults.setValue(newValue, forKey: storageKey) }
    }
}
