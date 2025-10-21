import Foundation
import UIKit

/// Handler for opening app settings
///
/// **Why allow web to open settings?**
/// - Enables permission prompts ("Grant camera access in Settings")
/// - Improves UX by directly linking to settings when permissions are denied
/// - Reduces user frustration (no need to manually find app in Settings)
///
/// **Design Decision:**
/// Opens the app's settings page in the Settings app, not system-wide settings.
/// This is the most common use case and prevents security concerns about
/// accessing arbitrary system settings.
///
/// **iOS Behavior:**
/// Takes user to the app's specific settings page where they can manage:
/// - Permissions (camera, location, notifications, etc.)
/// - App-specific preferences
/// - Storage management
class OpenSettingsHandler: BridgeCommand {
    let actionName = "openSettings"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        DispatchQueue.main.async {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                Orchard.e("Could not create settings URL", [:])
                completion(.failure(.internalError("Could not create settings URL")))
                return
            }
            
            guard UIApplication.shared.canOpenURL(settingsUrl) else {
                Orchard.e("Cannot open settings URL", ["url": settingsUrl])
                completion(.failure(.internalError("Cannot open settings URL")))
                return
            }
            
            UIApplication.shared.open(settingsUrl) { success in
                if success {
                    completion(.success(nil))
                } else {
                    Orchard.e("Failed to open settings", [:])
                    completion(.failure(.internalError("Failed to open settings")))
                }
            }
        }
    }
}

