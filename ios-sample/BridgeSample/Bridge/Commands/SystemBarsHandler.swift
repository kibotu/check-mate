import Foundation
import UIKit
import SwiftUI

/// Shared state manager for system UI visibility
///
/// **Why use ObservableObject?**
/// - SwiftUI views can observe changes and update automatically
/// - Thread-safe updates through @Published property wrapper
/// - Allows bridge handlers to trigger UI updates across the app
///
/// **Why a singleton?**
/// - Status bar state is global to the app
/// - Needs to be accessible from both bridge handlers and SwiftUI views
/// - Simpler than passing environment objects through the view hierarchy
class SystemUIState: ObservableObject {
    static let shared = SystemUIState()
    
    @Published var isStatusBarHidden: Bool = false
    
    private init() {}
}

/// Handler for system bars (status bar and navigation bar)
///
/// **iOS Implementation:**
/// Unlike Android, iOS status bar control in SwiftUI requires a reactive approach:
/// - Uses @Published state to trigger view updates
/// - Views observe SystemUIState and apply .statusBarHidden() modifier
/// - Changes are applied immediately when the published value updates
///
/// **Design Decision:**
/// We invert the showStatusBar parameter (Android shows, iOS hides) to match
/// the iOS API's .statusBarHidden() modifier naming convention.
class SystemBarsHandler: BridgeCommand {
    let actionName = "systemBars"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let content = content, let showStatusBar = content["showStatusBar"] as? Bool else {
            completion(.failure(.invalidParameter("showStatusBar")))
            return
        }
        
        print("[Bridge] System bars command: showStatusBar=\(showStatusBar)")
        
        DispatchQueue.main.async {
            // Invert the value: showStatusBar=true means hide=false
            SystemUIState.shared.isStatusBarHidden = !showStatusBar
            completion(.success(nil))
        }
    }
}
