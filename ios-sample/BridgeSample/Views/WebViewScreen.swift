import SwiftUI

/// WebView screen that displays web content with JavaScript bridge
struct WebViewScreen: View {
    let url: URL
    let onBridgeReady: (JavaScriptBridge) -> Void
    
    var body: some View {
        WebViewContainer(
            url: url,
            onBridgeReady: onBridgeReady
        )
        .edgesIgnoringSafeArea(.all)
    }
}

