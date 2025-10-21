import Foundation
import WebKit

/// Main JavaScript bridge coordinator that handles communication between WebView and native code
///
/// **Why this architecture?**
/// - **Centralized Control**: Single point of contact for all JS↔Native communication
/// - **Version Management**: Enforces schema versioning to handle compatibility
/// - **Handler Registry**: Dynamically routes messages to appropriate handlers
/// - **Bidirectional Communication**: Supports both JS→Native calls and Native→JS events
///
/// **Design Decisions:**
/// - Uses weak references to avoid retain cycles with WebView and ViewController
/// - Implements `WKScriptMessageHandler` to receive messages from JavaScript
/// - Maintains handler registry to avoid massive switch statements
/// - Uses JSON for serialization to ensure both sides speak the same language
///
/// **Why NSObject?**
/// WKScriptMessageHandler is an Objective-C protocol, requiring NSObject inheritance.
/// This is a WebKit API requirement, not a design choice.
class JavaScriptBridge: NSObject, WKScriptMessageHandler {
    private var handlers: [BridgeCommand] = []
    private weak var webView: WKWebView?
    private weak var viewController: UIViewController?
    
    let name = "bridge"
    
    /// Schema version supported by this bridge
    ///
    /// **Why version the schema?**
    /// - Allows native app and web content to evolve independently
    /// - Enables graceful degradation when versions mismatch
    /// - Provides a mechanism to deprecate old command formats
    private let schemaVersion: Int = 1
    
    /// Controls whether lifecycle events are sent to JavaScript
    ///
    /// **Why opt-in?** Not all web pages need lifecycle events. Making it opt-in:
    /// - Reduces unnecessary traffic
    /// - Avoids sending events before the web page is ready to handle them
    /// - Gives web developers explicit control over when to start receiving events
    var lifecycleEventsEnabled = false
    
    init(webView: WKWebView, viewController: UIViewController) {
        self.webView = webView
        self.viewController = viewController
        super.init()
        
        setupMessageHandler()
        registerCommandHandlers()
        injectBridgeScript()
    }
    
    deinit {
        // Clean up the message handler when deallocating
        // **Why clean up here?** Prevents crashes from messages being sent to deallocated handlers
        // **Why not remove scripts?** User scripts may be shared across WKWebView instances
        // using the same configuration. Removing them could break other views.
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: name)
    }
    
    // MARK: - Setup
    
    /// Sets up the message handler that receives messages from JavaScript
    ///
    /// **Why remove before adding?**
    /// WKUserContentController crashes if you add a handler with a name that already exists.
    /// Since CoreWebViewController uses a shared WKWebViewConfiguration, multiple instances
    /// might try to register the same handler name. Removing first ensures idempotency.
    private func setupMessageHandler() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: name)
        webView?.configuration.userContentController.add(self, name: name)
    }
    
    /// Registers all available command handlers
    ///
    /// **Why centralize registration?**
    /// - Provides single source of truth for all available commands
    /// - Makes it easy to see all bridge capabilities at a glance
    /// - Enables conditional registration based on feature flags or configuration
    ///
    /// **Design Decision:**
    /// Handlers are grouped by category (Device, UI, Navigation, etc.) to make
    /// the list more maintainable and to help understand the bridge's scope.
    private func registerCommandHandlers() {
        // Device & System
        register(handler: DeviceInfoHandler())
        register(handler: NetworkStatusHandler())
        register(handler: OpenSettingsHandler())
        
        // UI
        register(handler: ShowToastHandler(viewController: viewController))
        register(handler: ShowAlertHandler(viewController: viewController))
        
        // Navigation
        register(handler: TopNavigationHandler())
        register(handler: BottomNavigationHandler())
        register(handler: NavigationHandler(viewController: viewController))
        register(handler: OpenUrlHandler())
        
        // System
        register(handler: SystemBarsHandler())
        register(handler: HapticHandler())
        register(handler: CopyToClipboardHandler())
        
        // Storage
        register(handler: SaveSecureDataHandler())
        register(handler: LoadSecureDataHandler())
        register(handler: RemoveSecureDataHandler())
        
        // Analytics
        register(handler: TrackEventHandler())
        register(handler: TrackScreenHandler())
        
        // Lifecycle & Refresh
        register(handler: LifecycleEventsHandler(bridge: self))
        register(handler: RefreshHandler())
    }
    
    /// Register a command handler
    ///
    /// **Why use an array instead of a dictionary?**
    /// - Simple and sufficient for our use case (small number of handlers)
    /// - Preserves registration order (useful for debugging)
    /// - Allows future enhancement: multiple handlers per action if needed
    private func register(handler: BridgeCommand) {
        handlers.append(handler)
        print("[Bridge] Registered handler for action: \(handler.actionName)")
    }
    
    /// Get handler for the given action
    private func handler(for action: String) -> BridgeCommand? {
        return handlers.first { $0.actionName == action }
    }
    
    /// Check if a version is supported
    ///
    /// **Why allow lower versions?** Ensures backward compatibility.
    /// New native versions can handle old web client messages. If the web uses
    /// an older schema, the native bridge still processes it correctly.
    private func isVersionSupported(_ version: Int) -> Bool {
        return version <= schemaVersion
    }
    
    /// Injects the JavaScript bridge code into the WebView
    ///
    /// **Why inject at document start?**
    /// Ensures the bridge API is available before any page scripts execute.
    /// This prevents race conditions and provides a consistent, reliable interface.
    ///
    /// **Why main frame only?**
    /// - Reduces overhead by not injecting into every iframe
    /// - Prevents potential security issues from untrusted iframe content
    /// - Simplifies the bridge lifetime and reduces message noise
    private func injectBridgeScript() {
        let script = JavaScriptBridgeScript.source(schemaVersion: schemaVersion)
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView?.configuration.userContentController.addUserScript(userScript)
        
        print("[Bridge] Bridge script injected (schema version \(schemaVersion))")
    }
    
    // MARK: - WKScriptMessageHandler
    
    /// Receives messages from JavaScript through the WebKit message handler
    ///
    /// **Why check the message name?** Although we only register for "Bridge",
    /// defensive programming prevents issues if other message handlers are added later.
    ///
    /// **Why expect a String body?** JavaScript sends JSON-encoded strings, not objects.
    /// This is a WebKit limitation: only certain types can cross the JS/Native boundary.
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == name else { return }
        
        guard let body = message.body as? String else {
            print("[Bridge] Received invalid message body")
            return
        }
        
        handleMessage(body)
    }
    
    // MARK: - Message Handling
    
    /// Processes incoming messages from JavaScript
    ///
    /// **Why fail silently for unsupported versions?**
    /// When the web content is newer than the app, it might send messages with
    /// features we don't support. Failing silently allows the web to gracefully
    /// degrade rather than breaking completely. The web side should check the
    /// bridge version and adjust behavior accordingly.
    ///
    /// **Why use weak self in completion?**
    /// Handler operations can be async and long-running. If the bridge is
    /// deallocated before the handler completes, we shouldn't retain it just
    /// to send a response that nothing can receive.
    private func handleMessage(_ messageString: String) {
        guard let data = messageString.data(using: .utf8) else {
            print("[Bridge] Could not convert message to data")
            return
        }
        
        let decoder = JSONDecoder()
        
        guard let message = try? decoder.decode(JavaScriptBridgeMessage.self, from: data) else {
            print("[Bridge] Could not decode message: \(messageString)")
            sendError(id: "unknown", error: .invalidMessage)
            return
        }
        
        // Check schema version
        if !isVersionSupported(message.version) {
            print("[Bridge] Silently ignoring unsupported version: \(message.version)")
            // Silently ignore messages with unsupported versions (as per spec)
            return
        }
        
        let action = message.data.action
        let content = message.data.content?.mapValues { $0.value }
        
        print("[Bridge] Received action: \(action)")
        
        guard let handler = handler(for: action) else {
            print("[Bridge] Unknown action: \(action)")
            sendError(id: message.id, error: .unknownAction(action))
            return
        }
        
        handler.handle(content: content) { [weak self] result in
            switch result {
            case .success(let responseData):
                self?.sendSuccess(id: message.id, data: responseData)
            case .failure(let error):
                self?.sendError(id: message.id, error: error)
            }
        }
    }
    
    // MARK: - Sending Responses
    
    private func sendSuccess(id: String, data: [String: Any]?) {
        let response = JavaScriptBridgeResponse(
            id: id,
            success: true,
            data: data?.mapValues { AnyCodable($0) },
            error: nil
        )
        
        sendResponse(response)
    }
    
    private func sendError(id: String, error: BridgeError) {
        let response = JavaScriptBridgeResponse(
            id: id,
            success: false,
            data: nil,
            error: JavaScriptBridgeResponse.ErrorInfo(
                code: error.code,
                message: error.message
            )
        )
        
        sendResponse(response)
    }
    
    /// Sends a response back to JavaScript
    ///
    /// **Why use evaluateJavaScript instead of postMessage?**
    /// Native to JS communication requires evaluating JavaScript code. There's no
    /// built-in reverse message channel in WKWebView.
    ///
    /// **Why dispatch to main queue?**
    /// WKWebView JavaScript evaluation must happen on the main thread. Handler
    /// completions might come from background threads (network, storage, etc.),
    /// so we explicitly dispatch to main to ensure thread safety.
    ///
    /// **Why use double underscore prefix (__bridge)?**
    /// Signals these are internal bridge functions, not part of the public API.
    /// Reduces chance of naming conflicts with web application code.
    private func sendResponse(_ response: JavaScriptBridgeResponse) {
        let encoder = JSONEncoder()
        
        guard let data = try? encoder.encode(response),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("Failed to encode bridge response", [:])
            return
        }
        
        let script = "window.__bridgeHandleResponse(\(jsonString));"
        
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Failed to send bridge response: \(error)", [:])
                }
            }
        }
    }
    
    // MARK: - Native to Web Communication
    
    /// Send a message from native to web (fire-and-forget, no response expected)
    ///
    /// **Why have native-to-web messaging?**
    /// Enables reactive patterns where native code can notify JavaScript about events:
    /// - Lifecycle changes (app backgrounded/foregrounded)
    /// - Deep link activations
    /// - Push notification arrivals
    /// - System state changes (network status, etc.)
    ///
    /// **Why no response mechanism here?**
    /// This is event-based, not request-based. Native broadcasts events and
    /// doesn't need acknowledgment. This simplifies the flow and prevents
    /// deadlocks or coordination issues.
    func sendToWeb(action: String, content: [String: Any]? = nil) {
        let message: [String: Any] = [
            "data": [
                "action": action,
                "content": content ?? [:]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize message to web", [:])
            return
        }
        
        let script = "window.__bridgeReceiveNativeMessage(\(jsonString));"
        
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Failed to send message to web: \(error)", [:])
                }
            }
        }
    }
    
    // MARK: - Lifecycle Events
    
    /// Notifies JavaScript about lifecycle events
    ///
    /// **Why gate with lifecycleEventsEnabled?**
    /// - Not all web pages need lifecycle events
    /// - Prevents sending events before web page registers handlers (would be lost)
    /// - Reduces unnecessary message traffic
    /// - Gives web developers explicit control via the lifecycleEvents command
    func notifyLifecycleEvent(_ event: String) {
        guard lifecycleEventsEnabled else { return }
        sendToWeb(action: "lifecycle", content: ["event": event])
    }
}

