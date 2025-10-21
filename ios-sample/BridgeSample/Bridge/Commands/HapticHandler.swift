import Foundation
import UIKit

/// Handler for haptic feedback
///
/// **Why provide haptic feedback to web?**
/// - Creates more immersive experiences (games, interactive content)
/// - Provides tactile confirmation of user actions
/// - Web APIs don't have native haptic support on iOS
/// - Matches native app feel for hybrid experiences
///
/// **Design Decision:**
/// Uses UIImpactFeedbackGenerator with medium style as a reasonable default.
/// Could be extended to support different haptic patterns (light, heavy, etc.)
/// if needed by passing style as a parameter.
class HapticHandler: BridgeCommand {
    let actionName = "haptic"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let vibrate = content?["vibrate"] as? Bool, vibrate else {
            completion(.success(nil))
            return
        }
        
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            completion(.success(nil))
        }
    }
}

