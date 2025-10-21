import Foundation
import UIKit

/// Handler for showing alert dialogs
///
/// **Why allow web to show alerts?**
/// - Native alerts look and feel better than web-based modals
/// - Provides consistent UX across the app
/// - Enables confirmation dialogs, warnings, and important messages
/// - Users trust native alerts more than web popups
///
/// **Design Decision:**
/// Supports custom buttons via the `buttons` parameter. If not provided,
/// defaults to a single "OK" button. This keeps the simple case simple
/// while allowing more complex alert dialogs when needed.
///
/// **Limitation:**
/// Current implementation doesn't report which button was clicked back to JavaScript.
/// This could be enhanced if needed by adding a callback mechanism.
class ShowAlertHandler: BridgeCommand {
    let actionName = "showAlert"
    
    weak var viewController: UIViewController?
    
    init(viewController: UIViewController?) {
        self.viewController = viewController
    }
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let title = content?["title"] as? String,
              let message = content?["message"] as? String else {
            completion(.failure(.invalidParameter("title or message")))
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            if let buttons = content?["buttons"] as? [String] {
                for buttonTitle in buttons {
                    alert.addAction(UIAlertAction(title: buttonTitle, style: .default))
                }
            } else {
                alert.addAction(UIAlertAction(title: "OK", style: .default))
            }
            
            self?.viewController?.present(alert, animated: true)
            completion(.success(nil))
        }
    }
}

