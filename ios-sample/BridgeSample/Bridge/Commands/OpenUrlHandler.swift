import Foundation
import UIKit

/// Handler for simple URL opening
///
/// **Why have both openUrl and navigation commands?**
/// - **openUrl**: Simple, always opens externally (system browser)
/// - **navigation**: More complex, supports internal navigation and external with flag
///
/// **Design Decision:**
/// Keeps the simple case simple. For straightforward "open this URL in Safari"
/// scenarios, openUrl is more intuitive than navigation with external flag.
///
/// **Use Cases:**
/// - Open external websites (terms of service, help pages)
/// - Open other apps via deep links (tel:, mailto:, custom schemes)
/// - Share content via URLs (twitter://, instagram://)
///
/// **Security Note:**
/// Opens URLs without validation. This is acceptable because:
/// - Web content is trusted
/// - iOS handles URL scheme permissions (prompts for tel:, mailto:, etc.)
/// - System prevents malicious URL schemes
class OpenUrlHandler: BridgeCommand {
    let actionName = "openUrl"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let urlString = content?["url"] as? String,
              let url = URL(string: urlString) else {
            completion(.failure(.invalidParameter("url")))
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
            completion(.success(nil))
        }
    }
}

