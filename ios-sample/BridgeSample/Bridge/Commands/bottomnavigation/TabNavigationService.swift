import Foundation
import SwiftUI
import Orchard

/// Service to manage tab navigation across the app
///
/// **Why a shared service?**
/// - Allows bridge commands to trigger tab switches from anywhere
/// - Provides a single source of truth for the selected tab
/// - Uses Combine's @Published to reactively update the UI
class TabNavigationService: ObservableObject {
    @Published var selectedTab: Int = 0
    
    static let shared = TabNavigationService()
    
    private init() {}
    
    /// Switch to a specific tab
    func switchToTab(_ index: Int) {
        DispatchQueue.main.async {
            withAnimation {
                self.selectedTab = index
            }
            Orchard.v("[TabNavigationService] Switched to tab \(index)")
        }
    }
}

