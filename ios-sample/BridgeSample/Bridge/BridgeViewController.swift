//
//  BridgeViewController.swift
//  BridgeSample
//
//  Main view controller managing WKWebView and bridge communication
//

import UIKit
import WebKit
import Combine

class BridgeViewController: UIViewController, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isReady = false
    @Published var lastAction: String?
    
    // MARK: - Private Properties
    private var webView: WKWebView!
    private var actionHandler: BridgeActionHandler!
    private var pendingRequests: [String: PendingRequest] = [:]
    private var debugMode = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupWebView()
        actionHandler = BridgeActionHandler(viewController: self)
        loadLocalHTML()
    }
    
    deinit {
        print("[Bridge] View controller deallocating, cleaning up...")
        
        // Cancel all pending requests
        for (id, continuation) in pendingRequests {
            print("[Bridge] Canceling pending request: \(id)")
            continuation.resume(throwing: BridgeError.unknown("View controller deallocated"))
        }
        pendingRequests.removeAll()
        
        // Remove message handler
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "bridge")
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // Inject bridge JavaScript at document start
        let script = WKUserScript(
            source: BridgeJavaScript.source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(script)
        
        // Register message handler to receive messages from web
        userContentController.add(self, name: "bridge")
        
        configuration.userContentController = userContentController
        
        // Enable features
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // Create web view
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        
        // Add to view hierarchy
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("[Bridge] WebView setup complete")
    }
    
    private func loadLocalHTML() {
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html"),
              let htmlURL = URL(string: "file://\(htmlPath)") else {
            print("[Bridge] Error: Could not find index.html")
            return
        }
        
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        print("[Bridge] Loading local HTML: \(htmlURL.path)")
    }
    
    private func scheduleDemoEvent() {
        // Send a demo event after 5 seconds (like Android does)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.sendEventToWeb(
                action: "nativeEvent",
                content: [
                    "type": "demo",
                    "message": "Hello from iOS!",
                    "timestamp": Date().timeIntervalSince1970
                ]
            )
        }
    }
    
    // MARK: - Public Methods
    
    func reload() {
        webView.reload()
    }
    
    func toggleDebug() {
        debugMode.toggle()
        
        let js = "window.bridge?.setDebug(\(debugMode))"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("[Bridge] Error toggling debug: \(error)")
            } else {
                print("[Bridge] Debug mode: \(self.debugMode)")
            }
        }
    }
    
    // MARK: - Native → Web Communication
    
    /// Send a fire-and-forget event to the web side
    func sendEventToWeb(action: String, content: [String: Any]) {
        let message: [String: Any] = [
            "data": [
                "action": action,
                "content": content
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[Bridge] Error: Failed to serialize message")
            return
        }
        
        let js = "window.bridge._onNativeMessage(\(jsonString))"
        
        // Ensure we're on the main thread for WebView operations
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[Bridge] Error sending event to web: \(error)")
                } else {
                    print("[Bridge] Sent event to web: \(action)")
                }
            }
        }
    }
    
    /// Call a web function and await response
    func callWeb(action: String, content: [String: Any]) async throws -> Any? {
        let id = UUID().uuidString
        let message: [String: Any] = [
            "data": [
                "action": action,
                "content": content
            ],
            "id": id
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw BridgeError.jsonSerializationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Store pending request
            pendingRequests[id] = continuation
            
            let js = "window.bridge._onNativeMessage(\(jsonString))"
            
            // Ensure we're on the main thread for WebView operations
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        self.pendingRequests.removeValue(forKey: id)
                        continuation.resume(throwing: BridgeError.unknown(error.localizedDescription))
                    }
                }
            }
            
            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if let pending = self.pendingRequests.removeValue(forKey: id) {
                    pending.resume(throwing: BridgeError.timeout)
                }
            }
        }
    }
    
    // MARK: - Test Methods
    
    func sendTestEvent() {
        sendEventToWeb(
            action: "testEvent",
            content: [
                "message": "Hello from native!",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    func testCallWeb() async {
        do {
            let result = try await callWeb(
                action: "getWebState",
                content: [:]
            )
            print("[Bridge] Web state result: \(String(describing: result))")
        } catch {
            print("[Bridge] Error calling web: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendResult(id: String, result: Any?) {
        let response: [String: Any] = [
            "id": id,
            "result": result ?? NSNull()
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: response),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[Bridge] Error: Failed to serialize result")
            return
        }
        
        let js = "window.bridge._onNativeResponse(\(jsonString))"
        
        // Ensure we're on the main thread for WebView operations
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[Bridge] Error sending result: \(error)")
                }
            }
        }
    }
    
    private func sendError(id: String, error: BridgeError) {
        let response: [String: Any] = [
            "id": id,
            "error": [
                "code": error.code,
                "message": error.localizedDescription
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: response),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[Bridge] Error: Failed to serialize error")
            return
        }
        
        let js = "window.bridge._onNativeResponse(\(jsonString))"
        
        // Ensure we're on the main thread for WebView operations
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[Bridge] Error sending error: \(error)")
                }
            }
        }
    }
}

// MARK: - WKScriptMessageHandler

extension BridgeViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "bridge",
              let body = message.body as? [String: Any] else {
            print("[Bridge] Error: Invalid message format")
            return
        }
        
        print("[Bridge] Received message from web: \(body)")
        
        // Check if this is a response to a native→web call
        if let id = body["id"] as? String,
           body["data"] == nil,  // No data means it's a response
           let pending = pendingRequests.removeValue(forKey: id) {
            
            if let error = body["error"] as? [String: Any] {
                let errorMessage = error["message"] as? String ?? "Unknown error"
                let errorCode = error["code"] as? String ?? "UNKNOWN"
                print("[Bridge] Web returned error: [\(errorCode)] \(errorMessage)")
                pending.resume(throwing: BridgeError.unknown(errorMessage))
            } else {
                print("[Bridge] Web returned result for call: \(id)")
                pending.resume(returning: body["result"])
            }
            return
        }
        
        // Extract message components for regular web→native calls
        guard let data = body["data"] as? [String: Any],
              let action = data["action"] as? String else {
            print("[Bridge] Error: Missing action in message")
            return
        }
        
        let content = data["content"] as? [String: Any]
        let id = body["id"] as? String
        
        // Update last action for UI
        DispatchQueue.main.async {
            self.lastAction = action
        }
        
        // Handle the action
        Task {
            do {
                let result = try await actionHandler.handleAction(action, content: content)
                
                // Send response if ID present (request-response pattern)
                if let id = id {
                    await MainActor.run {
                        self.sendResult(id: id, result: result)
                    }
                }
            } catch let error as BridgeError {
                print("[Bridge] Error handling action: \(error)")
                
                if let id = id {
                    await MainActor.run {
                        self.sendError(id: id, error: error)
                    }
                }
            } catch {
                print("[Bridge] Unexpected error: \(error)")
                
                if let id = id {
                    await MainActor.run {
                        self.sendError(id: id, error: .unknown(error.localizedDescription))
                    }
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension BridgeViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[Bridge] Web page loaded")
        
        DispatchQueue.main.async {
            self.isReady = true
        }
        
        // Schedule demo event (like Android does)
        scheduleDemoEvent()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[Bridge] Navigation failed: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[Bridge] Provisional navigation failed: \(error)")
    }
}

