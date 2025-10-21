import Foundation

/// Handler for bottom navigation control
///
/// **Why allow web to control bottom navigation?**
/// - Web content sometimes needs full-screen experiences (no tab bar)
/// - Prevents tab bar from obscuring important content
/// - Enables immersive experiences (videos, games, forms)
/// - Matches native app patterns where tab bar hides in detail views
///
/// **Design Decision:**
/// Simpler than TopNavigationHandler - only controls visibility, not content.
/// This is intentional because:
/// - Bottom navigation structure is fixed (defined by app architecture)
/// - Web content shouldn't redefine the entire tab bar
/// - Visibility is the only control that makes sense for web content
///
/// **Use Cases:**
/// - Hide during onboarding flows
/// - Hide on full-screen content (images, videos)
/// - Hide on forms to maximize screen space
/// - Show when user needs to navigate between sections
class BottomNavigationHandler: BridgeCommand {
    let actionName = "bottomNavigation"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let isVisible = content?["isVisible"] as? Bool else {
            completion(.failure(.invalidParameter("isVisible")))
            return
        }
        
        DispatchQueue.main.async {
            let bottomNavService = BottomNavigationService.shared
            bottomNavService.setVisible(isVisible)
            completion(.success(nil))
        }
    }
}

