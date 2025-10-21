import Foundation

/// Handler for removing secure data from Keychain
///
/// **Why have a separate remove command?**
/// - Makes the API explicit and clear (better than saving empty string)
/// - Properly deletes the Keychain item (not just overwriting with empty value)
/// - Prevents accumulation of unused Keychain items
///
/// **Design Decision:**
/// KeychainHelper.delete returns true even if the key doesn't exist (errSecItemNotFound).
/// This makes the operation idempotent - calling remove multiple times is safe.
class RemoveSecureDataHandler: BridgeCommand {
    let actionName = "removeSecureData"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let key = content?["key"] as? String else {
            completion(.failure(.invalidParameter("key")))
            return
        }
        
        let success = KeychainHelper.delete(key: key)
        
        if success {
            completion(.success(nil))
        } else {
            completion(.failure(.internalError("Failed to remove from keychain")))
        }
    }
}

