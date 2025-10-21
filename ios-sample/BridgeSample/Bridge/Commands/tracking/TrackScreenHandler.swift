import Foundation

/// Handler for tracking screen views (fire-and-forget)
///
/// **Why separate from trackEvent?**
/// - Screen views are a special type of analytics event
/// - Many analytics services treat page views differently than events
/// - Allows different handling/routing in analytics pipeline
/// - Follows standard analytics SDK patterns (screenView vs event)
///
/// **Design Decision:**
/// Fire-and-forget like trackEvent. Screen tracking is observational
/// and shouldn't impact user experience if it fails.
///
/// **Integration:**
/// Uses C24Tracker with Firebase's standard screen_view event name,
/// following Firebase Analytics conventions for screen tracking.
class TrackScreenHandler: BridgeCommand {
    let actionName = "trackScreen"
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        guard let screenName = content?["screenName"] as? String else {
            completion(.failure(.invalidParameter("screenName")))
            return
        }
        
        let screenClass = content?["screenClass"] as? String
        
        // Build parameters following Firebase Analytics conventions
        var parameters: [String: Any] = [
            "screen_name": screenName
        ]
        
        if let screenClass = screenClass {
            parameters["screen_class"] = screenClass
        }
        
        // Track screen view using C24Tracker (forwards to Firebase Analytics)
        let trackingEvent = BridgeScreenTrackingEvent(
            name: "screen_view",
            parameters: parameters
        )
        print(trackingEvent)
        
        print("[Bridge] Track screen: \(screenName), class: \(String(describing: screenClass))")
        
        // Fire-and-forget: immediately return success
        completion(.success(nil))
    }
}

/// Wrapper to make bridge screen events conform to TrackingEvent protocol
private struct BridgeScreenTrackingEvent: TrackingEvent {
    let name: String
    let parameters: [String: Any]
}

