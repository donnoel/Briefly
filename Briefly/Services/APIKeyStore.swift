import Foundation

/// Stores the OpenAI API key in the Keychain.
final class APIKeyStore {
    static let shared = APIKeyStore()

    private let key = "openai_api_key"

    var apiKey: String? {
        get { KeychainStore.getString(for: key) }
        set {
            if let value = newValue, !value.isEmpty {
                _ = KeychainStore.setString(value, for: key)
            } else {
                KeychainStore.delete(key)
            }
        }
    }
}
