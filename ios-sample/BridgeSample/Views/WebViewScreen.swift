import SwiftUI

/// WebView screen that displays web content with JavaScript bridge
struct WebViewScreen: View {
    let url: URL
    let onBridgeReady: (JavaScriptBridge) -> Void
    var shouldRespectTopSafeArea: Bool = false
    var shouldRespectBottomSafeArea: Bool = false
    
    var body: some View {
        WebViewContainer(
            url: url,
            shouldRespectTopSafeArea: shouldRespectTopSafeArea,
            shouldRespectBottomSafeArea: shouldRespectBottomSafeArea,
            onBridgeReady: onBridgeReady
        )
    }
}

