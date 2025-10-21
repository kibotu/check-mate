import Foundation

/// Handler for top navigation control
///
/// **Why allow web to control top navigation?**
/// - Enables web content to customize the navigation bar based on context
/// - Provides seamless integration between web and native UI
/// - Allows web pages to hide/show navigation elements as needed
/// - Supports consistent UX across hybrid app experiences
///
/// **Design Decision:**
/// Uses a centralized TopNavigationService rather than directly manipulating
/// the view controller. This provides:
/// - Consistent navigation bar behavior across the app
/// - Centralized state management for navigation configuration
/// - Easier testing and debugging
/// - Single source of truth for navigation appearance
///
/// **Configuration Options:**
/// - **isVisible**: Show/hide the entire navigation bar
/// - **title**: Set navigation bar title
/// - **showUpArrow**: Show/hide back button
/// - **showDivider**: Show/hide bottom divider line
/// - **showLogo**: Show/hide app logo
/// - **showProfileIconWidget**: Show/hide profile icon
class TopNavigationHandler: BridgeCommand {
    let actionName = "topNavigation"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let content = content else {
            completion(.failure(.invalidParameter("content")))
            return
        }
        
        DispatchQueue.main.async {
            let topNavService = TopNavigationService.shared
            
            topNavService.update(
                isVisible: content["isVisible"] as? Bool,
                title: content["title"] as? String,
                showBackButton: content["showUpArrow"] as? Bool,
                showDivider: content["showDivider"] as? Bool,
                showLogo: content["showLogo"] as? Bool,
                showProfileIconWidget: content["showProfileIconWidget"] as? Bool
            )
            
            completion(.success(nil))
        }
    }
}

