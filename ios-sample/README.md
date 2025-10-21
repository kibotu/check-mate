# iOS Bridge Sample App

A sample iOS application demonstrating the JavaScript Bridge integration with SwiftUI.

## Architecture

The app follows the same structure as the Android sample:

### Components

1. **MainTabView** - Main container with bottom tab navigation
   - Tab 1: Bridge Demo (loads local `index.html`)
   - Tab 2: External Web (loads external website)

2. **TopNavigationView** - Customizable top navigation bar
   - Controlled via bridge commands from WebView
   - Supports title, back button, logo, profile icon
   - Can be shown/hidden dynamically

3. **BottomNavigationService** - Bottom tab bar state management
   - Controls visibility of bottom navigation
   - Managed via bridge commands

4. **WebViewContainer** - UIKit WKWebView wrapper for SwiftUI
   - Integrates JavaScriptBridge
   - Handles WebView lifecycle

5. **JavaScriptBridge** - Core bridge implementation
   - Bidirectional communication (JS ↔ Native)
   - Command handler registry
   - Schema versioning support

### Bridge Commands

All commands from `index.html` are supported:

- **Device & System**: `deviceInfo`, `networkState`, `openSettings`
- **UI Actions**: `showToast`, `showAlert`
- **Navigation Control**: `topNavigation`, `bottomNavigation`
- **System Bars**: `systemBars` (iOS has platform limitations)
- **Haptics**: `haptic`
- **Navigation**: `navigation` (internal/external URLs)
- **System Actions**: `copyToClipboard`
- **Lifecycle Events**: `lifecycleEvents`
- **Push Notifications**: Native → Web events
- **Secure Storage**: `saveSecureData`, `loadSecureData`, `removeSecureData`
- **Analytics**: `trackEvent`, `trackScreen`

## Project Structure

```
ios-sample/
├── BridgeSample/
│   ├── BridgeSampleApp.swift          # App entry point
│   ├── Views/                          # SwiftUI views
│   │   ├── MainTabView.swift          # Main tab container
│   │   ├── TopNavigationView.swift    # Top nav bar
│   │   ├── BottomNavigationService.swift # Bottom nav state
│   │   ├── WebViewContainer.swift     # WebView wrapper
│   │   └── WebViewScreen.swift        # WebView screen
│   ├── Bridge/                         # Bridge implementation
│   │   ├── JavaScriptBridge.swift     # Core bridge
│   │   ├── BridgeCommand.swift        # Command protocol
│   │   ├── JavaScriptBridgeMessage.swift # Message types
│   │   ├── JavaScriptBridgeScript.swift  # Injected JS
│   │   └── Commands/                   # Command handlers
│   └── Resources/
│       └── index.html                  # Bridge demo page
└── BridgeSample.xcodeproj/
```

## Building & Running

### Requirements

- Xcode 14.0+
- iOS 15.0+ deployment target
- Swift 5.0+

### Steps

1. Open `BridgeSample.xcodeproj` in Xcode
2. Select a simulator or device
3. Press `Cmd+R` to build and run

### Features

- ✅ Two-tab bottom navigation
- ✅ Controllable top navigation bar
- ✅ WebView with JavaScript Bridge
- ✅ All bridge commands implemented
- ✅ Bidirectional communication
- ✅ Push notification simulation
- ✅ Lifecycle event forwarding
- ✅ Secure storage with Keychain
- ✅ Schema versioning

## Key Differences from Android

1. **System Bars**: iOS implementation uses SwiftUI's `.statusBarHidden()` modifier with reactive state management
2. **Toast**: iOS uses native alerts instead of Android-style toasts
3. **WebView**: Uses WKWebView instead of Android WebView
4. **Navigation**: SwiftUI-based tab navigation instead of Compose Navigation

## Testing the Bridge

Open the app and interact with the bridge demo page:

1. **Device Info**: Shows iOS device details
2. **Network Status**: Shows current connectivity
3. **UI Controls**: Toggle top/bottom navigation visibility
4. **Navigation**: Test internal/external navigation
5. **Storage**: Test secure data persistence
6. **Lifecycle**: Enable events and background/foreground the app

## Architecture Decisions

### Why SwiftUI?

- Modern, declarative UI framework
- Better integration with Swift
- Cleaner state management with `@ObservedObject`
- Easier to maintain than UIKit

### Why Singleton Services?

`TopNavigationService.shared`, `BottomNavigationService.shared`, and `SystemUIState.shared` provide:
- Single source of truth for UI state
- Easy access from bridge handlers
- Observable state changes via `@Published`
- No need for complex dependency injection
- Reactive UI updates across the app

### Why UIViewRepresentable for WebView?

- WKWebView is UIKit-based
- `UIViewRepresentable` bridges UIKit → SwiftUI
- Provides full control over WKWebView configuration
- Enables proper bridge integration

## Troubleshooting

### Bridge not working?

1. Check browser console for JavaScript errors
2. Verify `index.html` is in Resources folder
3. Ensure all Swift files are added to Xcode target

### WebView not loading?

1. Check Info.plist for required keys
2. Verify file URL is correct
3. Check Xcode console for error messages

### Navigation not updating?

1. Ensure services are using `.shared` singleton
2. Check that `@ObservedObject` is properly connected
3. Verify DispatchQueue.main.async usage in handlers

## License

See LICENSE file in repository root.
