import Foundation
import UIKit

/// Handler for showing toast messages
///
/// **Why allow web to show toasts?**
/// - Provides consistent feedback mechanism across native and web content
/// - Enables web content to give quick feedback without custom UI
/// - Maintains platform conventions (iOS toasts look native)
///
/// **Design Decision:**
/// Uses UIAlertController as a simple toast implementation. While iOS doesn't have
/// native "toasts" like Android, this provides similar UX. Can be swapped for a
/// custom toast library without changing the bridge API.
///
/// **Why weak viewController?**
/// Avoids retain cycle. If the view controller is deallocated while a toast is showing,
/// the toast will auto-dismiss (UIAlertController behavior).
class ShowToastHandler: BridgeCommand {
    let actionName = "showToast"
    
    weak var viewController: UIViewController?
    
    init(viewController: UIViewController?) {
        self.viewController = viewController
    }
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let message = content?["message"] as? String else {
            completion(.failure(.invalidParameter("message")))
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // Using a simple alert as a toast replacement for iOS
            // Can be replaced with custom toast implementation without changing the bridge API
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            self?.viewController?.present(alert, animated: true)
            
            // Auto-dismiss after duration
            let duration = (content?["duration"] as? String) == "long" ? 3.5 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                alert.dismiss(animated: true)
            }
            
            completion(.success(nil))
        }
    }
}

