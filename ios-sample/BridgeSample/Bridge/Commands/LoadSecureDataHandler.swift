import Foundation

/// Handler for loading secure data from Keychain
///
/// **Why return NSNull instead of failing?**
/// - Distinguishes between "key doesn't exist" and "operation failed"
/// - Matches JavaScript semantics (null = no value, error = something went wrong)
/// - Allows web code to handle missing keys gracefully without error handling
///
/// **Design Decision:**
/// Always returns success, even when the key doesn't exist. This is intentional because:
/// - A missing key is not an error condition (similar to getting undefined in JS)
/// - Web code can check for null/undefined without try-catch
/// - Simplifies the web API: `const value = await loadSecureData(key)`
class LoadSecureDataHandler: BridgeCommand {
    let actionName = "loadSecureData"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let key = content?["key"] as? String else {
            completion(.failure(.invalidParameter("key")))
            return
        }
        
        if let value = KeychainHelper.load(key: key) {
            completion(.success(["value": value]))
        } else {
            completion(.success(["value": NSNull()]))
        }
    }
}

