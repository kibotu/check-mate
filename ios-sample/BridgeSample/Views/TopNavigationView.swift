import SwiftUI

/// Configuration for the top navigation bar
struct TopNavigationConfig {
    var isVisible: Bool = true
    var title: String? = "Bridge Demo"
    var showBackButton: Bool = false
    var showDivider: Bool = true
    var showLogo: Bool = false
    var showProfileIconWidget: Bool = false
}

/// Observable service for top navigation state
class TopNavigationService: ObservableObject {
    @Published var config = TopNavigationConfig()
    
    static let shared = TopNavigationService()
    
    private init() {}
    
    func configure(with config: TopNavigationConfig) {
        DispatchQueue.main.async {
            self.config = config
        }
    }
    
    func update(isVisible: Bool? = nil,
                title: String? = nil,
                showBackButton: Bool? = nil,
                showDivider: Bool? = nil,
                showLogo: Bool? = nil,
                showProfileIconWidget: Bool? = nil) {
        DispatchQueue.main.async {
            if let isVisible = isVisible {
                self.config.isVisible = isVisible
            }
            if let title = title {
                self.config.title = title
            }
            if let showBackButton = showBackButton {
                self.config.showBackButton = showBackButton
            }
            if let showDivider = showDivider {
                self.config.showDivider = showDivider
            }
            if let showLogo = showLogo {
                self.config.showLogo = showLogo
            }
            if let showProfileIconWidget = showProfileIconWidget {
                self.config.showProfileIconWidget = showProfileIconWidget
            }
        }
    }
}

/// Top navigation bar view
struct TopNavigationView: View {
    @ObservedObject var service = TopNavigationService.shared
    let onBackPressed: () -> Void
    
    var body: some View {
        if service.config.isVisible {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Back button
                    if service.config.showBackButton {
                        Button(action: onBackPressed) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                                .font(.system(size: 20, weight: .medium))
                        }
                    }
                    
                    // Logo or Title
                    if service.config.showLogo {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    } else if let title = service.config.title {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    // Profile icon
                    if service.config.showProfileIconWidget {
                        Button(action: {}) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 28))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                
                // Divider
                if service.config.showDivider {
                    Divider()
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

