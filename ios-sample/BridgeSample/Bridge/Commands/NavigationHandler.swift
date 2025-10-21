import Foundation
import UIKit

/// Handler for in-app and external navigation
///
/// **Why let web control navigation?**
/// - Web content needs to navigate to native screens for seamless UX
/// - Web needs to open external links in system browser for better UX
/// - Web needs programmatic "back" navigation for custom flows
///
/// **Design Decision:**
/// Supports three navigation patterns:
/// 1. **Go Back**: Pops navigation stack (mimics browser back button)
/// 2. **Internal Navigation**: Uses AppLinkRouter for native screen navigation
/// 3. **External Navigation**: Opens URLs in system browser (Safari)
///
/// **Why distinguish internal vs external?**
/// - Internal navigation keeps users in the app (better retention)
/// - External navigation is needed for links to websites/other apps
/// - Gives web content control over the user experience
class NavigationHandler: BridgeCommand {
    let actionName = "navigation"
    
    weak var viewController: UIViewController?
    
    init(viewController: UIViewController?) {
        self.viewController = viewController
    }
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let content = content else {
            completion(.failure(.invalidParameter("content")))
            return
        }
        
        // Handle go back
        if let goBack = content["goBack"] as? Bool, goBack {
            DispatchQueue.main.async { [weak self] in
                self?.viewController?.navigationController?.popViewController(animated: true)
                completion(.success(nil))
            }
            return
        }
        
        // Handle URL navigation
        guard let urlString = content["url"] as? String,
              let url = URL(string: urlString) else {
            completion(.failure(.invalidParameter("url")))
            return
        }
        
        let isExternal = content["external"] as? Bool ?? false
        
        DispatchQueue.main.async { [weak self] in
            if isExternal {
                // Open in external browser
                UIApplication.shared.open(url)
            } else {
//                // Open internally using AppLinkRouter
//                let appLinkRouter: AppLinkRouter = resolve()
//                appLinkRouter.open(url: url, from: .deepLink)
            }
            completion(.success(nil))
        }
    }
}

