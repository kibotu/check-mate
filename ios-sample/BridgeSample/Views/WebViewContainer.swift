import SwiftUI
import WebKit
import Orchard

/// SwiftUI wrapper for WKWebView with JavaScript bridge integration
struct WebViewContainer: UIViewControllerRepresentable {
    let url: URL
    let shouldRespectTopSafeArea: Bool
    let shouldRespectBottomSafeArea: Bool
    let onBridgeReady: (JavaScriptBridge) -> Void
    
    func makeUIViewController(context: Context) -> WebViewController {
        let controller = WebViewController()
        controller.url = url
        controller.shouldRespectTopSafeArea = shouldRespectTopSafeArea
        controller.shouldRespectBottomSafeArea = shouldRespectBottomSafeArea
        controller.onBridgeReady = onBridgeReady
        return controller
    }
    
    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {
        // Update URL if changed
        if uiViewController.webView.url != url {
            let request = URLRequest(url: url)
            uiViewController.webView.load(request)
        }
        
        // Update safe area settings if changed
        if uiViewController.shouldRespectTopSafeArea != shouldRespectTopSafeArea ||
           uiViewController.shouldRespectBottomSafeArea != shouldRespectBottomSafeArea {
            uiViewController.shouldRespectTopSafeArea = shouldRespectTopSafeArea
            uiViewController.shouldRespectBottomSafeArea = shouldRespectBottomSafeArea
            uiViewController.updateContentInsets()
        }
    }
}

/// UIViewController that hosts the WKWebView and manages the bridge
class WebViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var bridge: JavaScriptBridge?
    var url: URL?
    var onBridgeReady: ((JavaScriptBridge) -> Void)?
    var shouldRespectTopSafeArea: Bool = false
    var shouldRespectBottomSafeArea: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure WebView
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        
        // Create and attach bridge (now we have a proper view controller)
        let jsBridge = JavaScriptBridge(webView: webView, viewController: self)
        bridge = jsBridge
        onBridgeReady?(jsBridge)
        
        Orchard.v("[WebViewController] Bridge initialized")
        
        // Load URL
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateContentInsets()
    }
    
    /// Update webview content insets based on safe area requirements
    func updateContentInsets() {
        let safeInsets = view.safeAreaInsets
        
        let topInset: CGFloat = shouldRespectTopSafeArea ? safeInsets.top : 0
        let bottomInset: CGFloat = shouldRespectBottomSafeArea ? safeInsets.bottom : 0
        
        webView.scrollView.contentInset = UIEdgeInsets(
            top: topInset,
            left: 0,
            bottom: bottomInset,
            right: 0
        )
        
        // Also update scroll indicator insets to match
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
        
        Orchard.v("[WebViewController] Updated content insets - top: \(topInset), bottom: \(bottomInset)")
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Orchard.v("[WebView] Page loaded: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Orchard.e("[WebView] Navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Orchard.e("[WebView] Provisional navigation failed: \(error.localizedDescription)")
    }
}
