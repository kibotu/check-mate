import Foundation
import UIKit
import WebKit
import Orchard

/// Handles multiple navigation patterns: back navigation, internal/external URLs.
///
/// **Why combined command:**
/// Navigation actions are mutually exclusive - user does one at a time. Single command
/// simplifies web API (one call instead of multiple) for common navigation patterns.
///
/// **Why goBack:**
/// Allows web to trigger native back navigation. Priority order:
/// 1. WebView history (if available)
/// 2. Navigation controller pop (if in a stack)
/// 3. Dismiss view controller (if presented modally)
/// 4. Exit app (as last resort on root view controller)
///
/// **Why external option:**
/// Some URLs should open in browser (privacy policies, external sites) to make
/// clear they're leaving the app. External prevents deep link interception.
///
/// **Thread Safety:**
/// All UIKit operations must run on the main thread, hence the DispatchQueue.main.async
class NavigationHandler: BridgeCommand {
    let actionName = "navigation"
    
    weak var viewController: UIViewController?
    weak var webView: WKWebView?
    
    init(viewController: UIViewController?, webView: WKWebView? = nil) {
        self.viewController = viewController
        self.webView = webView
    }
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        let urlString = content?["url"] as? String ?? ""
        let isExternal = content?["external"] as? Bool ?? false
        let goBack = content?["goBack"] as? Bool ?? false
        
        Orchard.v("[NavigationHandler] url=\(urlString) external=\(isExternal) goBack=\(goBack)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(.failure(.internalError("Handler deallocated")))
                return
            }
            
            // Handle go back - mimics native back swipe gesture
            if goBack {
                // Strategy 1: Try WebView back navigation if there's history
                if let webView = self.webView, webView.canGoBack {
                    webView.goBack()
                    Orchard.v("[NavigationHandler] Navigated back in WebView history")
                    completion(.success(nil))
                    return
                }
                
                // Strategy 2: Try to pop the navigation controller if we're in a navigation stack
                if let navigationController = self.viewController?.navigationController,
                   navigationController.viewControllers.count > 1 {
                    navigationController.popViewController(animated: true)
                    Orchard.v("[NavigationHandler] Popped navigation controller")
                    completion(.success(nil))
                    return
                }
                
                // Strategy 3: Try dismissing if presented modally
                if let viewController = self.viewController,
                   viewController.presentingViewController != nil {
                    viewController.dismiss(animated: true) {
                        Orchard.v("[NavigationHandler] Dismissed modal view controller")
                        completion(.success(nil))
                    }
                    return
                }
                
                // Strategy 4: Last resort - exit the app (iOS doesn't encourage this, but it's what the user requested)
                // Note: This will cause the app to exit, which is against Apple's HIG but matches Android behavior
                Orchard.w("[NavigationHandler] No back navigation available, exiting app")
                exit(0)
            }
            
            // Handle URL navigation
            if !urlString.isEmpty {
                guard let url = URL(string: urlString) else {
                    completion(.failure(.invalidParameter("Invalid URL: \(urlString)")))
                    return
                }
                
                if isExternal {
                    // Open in external browser (Safari)
                    UIApplication.shared.open(url)
                    completion(.success(nil))
                } else {
                    // Internal navigation - switch to tab 2 (Web tab)
                    // This demonstrates internal app navigation triggered by the web content
                    Orchard.v("[NavigationHandler] Internal navigation to: \(urlString)")
                    TabNavigationService.shared.switchToTab(1)
                    completion(.success(nil))
                }
                return
            }
            
            // No valid navigation parameter provided
            completion(.failure(.invalidParameter("Missing navigation parameter")))
        }
    }
}

