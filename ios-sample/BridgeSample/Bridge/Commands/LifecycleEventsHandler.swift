import Foundation

/// Handler for lifecycle events
///
/// **Why opt-in lifecycle events?**
/// - Prevents sending events to web pages that don't care about them
/// - Avoids "lost events" problem (events sent before listener is registered)
/// - Gives web developers explicit control over when to start receiving events
/// - Reduces unnecessary message traffic for better performance
///
/// **Design Decision:**
/// Instead of automatically sending lifecycle events, web content must explicitly
/// enable them via bridge.call({data: {action: "lifecycleEvents", content: {enable: true}}}).
/// This follows the principle of explicit over implicit behavior.
class LifecycleEventsHandler: BridgeCommand {
    let actionName = "lifecycleEvents"
    
    weak var bridge: JavaScriptBridge?
    
    init(bridge: JavaScriptBridge?) {
        self.bridge = bridge
    }
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let enable = content?["enable"] as? Bool else {
            completion(.failure(.invalidParameter("enable")))
            return
        }
        
        bridge?.lifecycleEventsEnabled = enable
        
        Orchard.d("[Bridge] Lifecycle events \(enable ? "enabled" : "disabled")")
        completion(.success(nil))
    }
}

