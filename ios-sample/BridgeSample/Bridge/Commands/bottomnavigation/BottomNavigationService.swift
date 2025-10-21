import SwiftUI

/// Configuration for bottom navigation
struct BottomNavigationConfig {
    var isVisible: Bool = true
}

/// Observable service for bottom navigation state
class BottomNavigationService: ObservableObject {
    @Published var config = BottomNavigationConfig()
    
    static let shared = BottomNavigationService()
    
    private init() {}
    
    func configure(with config: BottomNavigationConfig) {
        DispatchQueue.main.async {
            self.config = config
        }
    }
    
    func setVisible(_ isVisible: Bool) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.config.isVisible = isVisible
            }
        }
    }
}

