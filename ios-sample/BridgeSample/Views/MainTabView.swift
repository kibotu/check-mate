import SwiftUI

/// Main tab view with bottom navigation
struct MainTabView: View {
    @State private var currentBridge: JavaScriptBridge?
    @ObservedObject private var bottomNavService = BottomNavigationService.shared
    @ObservedObject private var topNavService = TopNavigationService.shared
    @ObservedObject private var tabNavService = TabNavigationService.shared
    @ObservedObject private var systemUIState = SystemUIState.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation
            TopNavigationView(onBackPressed: {
                print("[MainTabView] Back button pressed")
            })
            
            // Content
            ZStack {
                // Tab 1 - Bridge Demo
                if tabNavService.selectedTab == 0 {
                    WebViewScreen(
                        url: getLocalFileURL(filename: "index.html"),
                        onBridgeReady: { bridge in
                            currentBridge = bridge
                            print("[MainTabView] Bridge ready for Tab 1")
                            startPushNotificationSimulation(bridge: bridge)
                        }
                    )
                    .transition(.opacity)
                }
                
                // Tab 2 - External Website
                if tabNavService.selectedTab == 1 {
                    WebViewScreen(
                        url: URL(string: "https://portfolio.kibotu.net/")!,
                        onBridgeReady: { bridge in
                            currentBridge = bridge
                            print("[MainTabView] Bridge ready for Tab 2")
                        }
                    )
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Navigation
            if bottomNavService.config.isVisible {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 0) {
                        // Tab 1 - Home
                        TabBarItem(
                            icon: "house.fill",
                            label: "Home",
                            isSelected: tabNavService.selectedTab == 0
                        ) {
                            tabNavService.switchToTab(0)
                        }
                        
                        // Tab 2 - Web
                        TabBarItem(
                            icon: "globe",
                            label: "Web",
                            isSelected: tabNavService.selectedTab == 1
                        ) {
                            tabNavService.switchToTab(1)
                        }
                    }
                    .frame(height: 50)
                    .background(Color(UIColor.systemBackground))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .statusBarHidden(systemUIState.isStatusBarHidden)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            currentBridge?.notifyLifecycleEvent("focused")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            currentBridge?.notifyLifecycleEvent("defocused")
        }
    }
    
    /// Get the URL for a local HTML file in the Resources folder
    private func getLocalFileURL(filename: String) -> URL {
        if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".html", with: ""), withExtension: "html", subdirectory: "Resources") {
            return url
        }
        // Fallback: try without subdirectory
        return Bundle.main.url(forResource: filename.replacingOccurrences(of: ".html", with: ""), withExtension: "html") ?? URL(string: "about:blank")!
    }
    
    /// Start simulating push notifications (like in Android sample)
    private func startPushNotificationSimulation(bridge: JavaScriptBridge) {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 7...15), repeats: true) { _ in
            bridge.sendToWeb(action: "onPushNotification", content: [
                "url": "https://www.google.com",
                "message": "Lorem Ipsum"
            ])
        }
    }
}

/// Custom tab bar item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

