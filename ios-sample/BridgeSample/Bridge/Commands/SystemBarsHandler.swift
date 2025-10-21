import Foundation

/// Handler for system bars (status bar and navigation bar)
///
/// **Why have this if it's not implemented?**
/// - Maintains API compatibility with Android bridge
/// - Prevents errors when web code calls this command
/// - Placeholder for future implementation if requirements change
/// - Better to no-op than to throw an error
///
/// **iOS Limitation:**
/// iOS has strict controls over status bar visibility. Changes require:
/// - Info.plist configuration (UIViewControllerBasedStatusBarAppearance)
/// - View controller override of prefersStatusBarHidden
/// - Cannot be changed dynamically from arbitrary code
///
/// **Design Decision:**
/// Returns success to indicate the command was received, even though
/// it doesn't do anything. This prevents breaking web code that expects
/// this command to exist on both platforms.
class SystemBarsHandler: BridgeCommand {
    let actionName = "systemBars"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        // iOS doesn't allow programmatic control of status bar visibility from UIViewController
        // This would need to be handled at the app level with Info.plist settings
        // For now, we acknowledge the command without errors to maintain cross-platform compatibility
        Orchard.d("[Bridge] System bars command received (limited support on iOS)")
        completion(.success(nil))
    }
}

