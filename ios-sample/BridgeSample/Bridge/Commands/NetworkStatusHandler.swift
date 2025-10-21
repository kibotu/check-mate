import Foundation

/// Handler for network status checks
///
/// **Why expose network status to web?**
/// - Enables web content to adapt to offline/online state
/// - Allows preemptive error messages ("You appear to be offline")
/// - Supports offline-first strategies in web code
/// - Helps web decide whether to attempt network requests
/// - Enables web to optimize content/quality based on connection type
///
/// **Design Decision:**
/// Uses dependency injection (@CoreInject) to access the app's network
/// availability service. This ensures consistency between native and web
/// network state, and makes testing easier.
///
/// **Connection Type Detection:**
/// Returns the actual connection type (wifi, cellular, none, or unknown)
/// by leveraging iOS SystemConfiguration APIs via NetworkReachabilityManager.
class NetworkStatusHandler: BridgeCommand {
    let actionName = "networkState"
    
    @CoreInject private var networkAvailability: NetworkAvailabilityProtocol
    
    func handle(
        content: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, BridgeError>) -> Void
    ) {
        let networkStatus = networkAvailability.networkStatus
        
        let status: [String: Any] = [
            "connected": networkStatus.isReachable,
            "type": connectionTypeString(networkStatus.connectionType)
        ]
        
        completion(.success(status))
    }
    
    private func connectionTypeString(_ type: NetworkStatus.ConnectionType) -> String {
        switch type {
        case .none:
            return "none"
        case .unknown:
            return "unknown"
        case .wifi:
            return "wifi"
        case .cellular:
            return "cellular"
        }
    }
}

