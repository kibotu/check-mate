# iOS Bridge Sample App  [![iOS CI](https://github.com/kibotu/check-mate/actions/workflows/ios.yml/badge.svg)](https://github.com/kibotu/check-mate/actions/workflows/ios.yml)

A complete iOS sample app demonstrating the JavaScript Bridge specification for bidirectional communication between native iOS and WebView.

## Overview

This sample app implements the complete bridge specification with:

- ✅ **Minimal API**: Just `call()` and `on()` methods
- ✅ **Pure JSON**: No method/param parsing, just JSON in/out
- ✅ **Async/await**: Modern async patterns throughout
- ✅ **Request-Response & Fire-and-Forget**: Both patterns supported
- ✅ **Complete Examples**: Device info, permissions, UI, storage, analytics
- ✅ **Production Ready**: Error handling, timeouts, debug mode

## Project Structure

```
ios-sample/
├── BridgeSample/
│   ├── BridgeSampleApp.swift       # Main app entry point
│   ├── ContentView.swift           # SwiftUI main view
│   ├── Bridge/
│   │   ├── WebViewBridge.swift     # Bridge JavaScript & error types
│   │   ├── BridgeViewController.swift  # WKWebView controller & message handling
│   │   └── BridgeActions.swift     # Native action implementations
│   ├── Resources/
│   │   └── index.html             # Sample web page with bridge demos
│   └── Info.plist
└── BridgeSample.xcodeproj/
```

## Requirements

- **Xcode**: 14.0 or later
- **iOS**: 15.0 or later
- **Swift**: 5.0 or later

## Getting Started

### 1. Open the Project

```bash
cd ios-sample
open BridgeSample.xcodeproj
```

### 2. Build and Run (Xcode GUI)

1. Select a simulator or device from the scheme selector
2. Press `Cmd + R` to build and run
3. The app will launch with a WebView showing the bridge demo

### 3. Build and Run (Command Line)

Alternatively, you can build and run from the command line:

#### Step 1: List Available Simulators

```bash
xcrun simctl list devices available | grep -E "iPhone|iPad"
```

This will show all available simulators, for example:
```
iPhone 16 Pro Max (96A52C46-65B2-4706-8997-38C45AC9623A) (Shutdown)
iPhone 17 Pro Max (6E61BF3A-F907-4617-898B-1CA4C8EAD012) (Shutdown)
```

#### Step 2: Build the Project

```bash
cd ios-sample
xcodebuild \ 
  -project BridgeSample.xcodeproj \
  -scheme BridgeSample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  clean build
```

Replace `iPhone 17 Pro Max` with your desired simulator name from Step 1.

#### Step 3: Boot the Simulator

```bash
xcrun simctl boot "iPhone 17 Pro Max"
```

Note: If the simulator is already running, this command will return an error but you can ignore it.

#### Step 4: Install the App

```bash
xcrun simctl install "iPhone 17 Pro Max" \
  ~/Library/Developer/Xcode/DerivedData/BridgeSample-*/Build/Products/Debug-iphonesimulator/BridgeSample.app
```

Or with the exact path:
```bash
# Find the exact path first
find ~/Library/Developer/Xcode/DerivedData -name "BridgeSample.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null

# Then install using that path
xcrun simctl install "iPhone 17 Pro Max" /path/to/BridgeSample.app
```

#### Step 5: Launch the App

```bash
xcrun simctl launch "iPhone 17 Pro Max" com.example.bridgesample
```

#### Step 6: Open Simulator UI (Optional)

If the Simulator window is not visible:

```bash
open -a Simulator
```

#### All-in-One Script

You can combine all steps into a single script:

```bash
#!/bin/bash

SIMULATOR_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.example.bridgesample"
PROJECT_DIR="ios-sample"

# Build
echo "Building project..."
cd "$PROJECT_DIR"
xcodebuild -project BridgeSample.xcodeproj \
  -scheme BridgeSample \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  clean build

# Boot simulator
echo "Booting simulator..."
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true

# Find and install app
echo "Installing app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "BridgeSample.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
xcrun simctl install "$SIMULATOR_NAME" "$APP_PATH"

# Launch app
echo "Launching app..."
xcrun simctl launch "$SIMULATOR_NAME" "$BUNDLE_ID"

# Open simulator UI
open -a Simulator

echo "✅ App is now running!"
```

### 4. Try the Features

The sample HTML page includes interactive demos for:

- **Device & System**: Get device info, request permissions, open settings, clipboard
- **UI Actions**: Show toast, alerts, set title, open URLs
- **Storage**: Save/load/remove data (uses UserDefaults)
- **Analytics**: Track events and screens (fire-and-forget pattern)

## Architecture

### Bridge JavaScript (WebViewBridge.swift)

The bridge JavaScript is injected into the WebView at document start. It provides:

```javascript
// Web → Native
await window.bridge.call({ data: { action: '...', content: {} } })

// Native → Web handler
window.bridge.on(async (message) => { ... })

// Lifecycle
await window.bridge.ready()
window.bridge.isReady

// Debug
window.bridge.setDebug(true)
```

### Native Message Handler (BridgeViewController.swift)

The view controller:
- Sets up WKWebView with bridge injection
- Receives messages via `WKScriptMessageHandler`
- Dispatches actions to `BridgeActionHandler`
- Sends responses back to JavaScript

### Action Handler (BridgeActions.swift)

Implements all native actions:

```swift
func handleAction(_ action: String, content: [String: Any]?) async throws -> Any?
```

Actions include:
- `getDeviceInfo()` - Device metadata
- `requestPermission(type)` - Camera, location permissions
- `showToast(message, duration)` - Native toast
- `showAlert(title, message, buttons)` - Native alert
- `setSecureData(key, value)` - Storage (UserDefaults)
- `trackEvent(name, properties)` - Analytics (console log)

### SwiftUI Integration (ContentView.swift)

SwiftUI wrapper around UIKit `WKWebView`:

```swift
BridgeWebViewRepresentable(controller: bridgeController)
```

Shows bridge status and provides toolbar actions.

## Usage Examples

### From Web to Native

```javascript
// Request-Response (await for result)
const deviceInfo = await window.bridge.call({
  data: { action: 'getDeviceInfo' }
});

// Fire-and-Forget (no await)
window.bridge.call({
  data: {
    action: 'trackEvent',
    content: { event: 'button_click' }
  }
});
```

### From Native to Web

```swift
// Fire-and-Forget Event
bridgeController.sendEventToWeb(
    action: "appStateChanged",
    content: ["state": "background"]
)

// Request-Response (await result)
let result = try await bridgeController.callWeb(
    action: "getWebState",
    content: [:]
)
```

## Key Implementation Details

### Thread Safety

All WebView operations run on the main thread:

```swift
DispatchQueue.main.async {
    self.webView.evaluateJavaScript(js)
}
```

### JSON Serialization

Proper JSON handling for native → web communication:

```swift
guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
      let jsonString = String(data: jsonData, encoding: .utf8) else {
    throw BridgeError.jsonSerializationFailed
}

let js = "window.bridge._onNativeMessage(\(jsonString))"
```

### Error Handling

Structured errors with codes:

```swift
enum BridgeError: LocalizedError {
    case invalidMessage
    case actionNotFound(String)
    case timeout
    // ...
    
    var code: String { ... }
}
```

### Request-Response Tracking

Pending requests tracked with continuations:

```swift
private var pendingRequests: [String: PendingRequest] = [:]

// Store pending request
pendingRequests[id] = continuation

// Resolve when response arrives
pending.resolve(result)
```

## Adding New Actions

To add a new native action:

1. **Add case to BridgeActions.swift**:

```swift
case "myNewAction":
    guard let param = content?["param"] as? String else {
        throw BridgeError.invalidParameters
    }
    return try await myNewAction(param: param)
```

2. **Implement the method**:

```swift
private func myNewAction(param: String) async throws -> [String: Any] {
    // Your implementation
    return ["result": "success"]
}
```

3. **Call from JavaScript**:

```javascript
const result = await window.bridge.call({
  data: {
    action: 'myNewAction',
    content: { param: 'value' }
  }
});
```

## Testing

### Run All Tests Button

The HTML page includes a "Run All Tests" button that executes multiple actions in sequence.

### Debug Mode

Toggle debug mode from:
- The menu (three dots) in the navigation bar
- JavaScript: `window.bridge.setDebug(true)`

Debug mode logs all bridge operations to the console.

### Manual Testing

Use the iOS Simulator to test:
- Different device types (iPhone, iPad)
- Different iOS versions
- Permission flows
- UI interactions

## Performance Considerations

- **Message Size**: Keep messages < 100KB (< 1MB max)
- **Frequency**: Debounce rapid calls to avoid flooding the bridge
- **Threading**: All WebView operations are on main thread
- **Memory**: Pending requests have 30s timeout to prevent leaks

## Security Notes

The current implementation:
- ✅ Validates all action names
- ✅ Checks parameter types
- ✅ Uses try-catch for all operations
- ⚠️ Storage uses UserDefaults (use Keychain for sensitive data)
- ⚠️ Loads local HTML (validate URLs for remote content)

For production:
1. Whitelist allowed actions
2. Validate all input parameters
3. Use HTTPS for web content
4. Implement rate limiting
5. Use Keychain for secure storage
6. Add Content Security Policy

## Troubleshooting

### Bridge not available

**Symptom**: `window.bridge` is undefined

**Solution**: 
- Check that bridge JavaScript is injected at document start
- Ensure WKUserScript is added to configuration
- Wait for `bridgeReady` event

### Actions not responding

**Symptom**: Calls timeout or return errors

**Solution**:
- Check console for error messages
- Enable debug mode
- Verify action name is correct
- Check parameter types match expected format

### WebView not loading

**Symptom**: Blank white screen

**Solution**:
- Check that `index.html` is in Resources folder
- Verify file is included in build target
- Check console for file loading errors
- Try absolute file:// URL path

### Permission requests not working

**Symptom**: Permissions always denied

**Solution**:
- Check Info.plist has usage descriptions
- Reset simulator: Device → Erase All Content and Settings
- For location, proper delegate setup is needed

## Next Steps

This sample demonstrates the core bridge. To extend it:

1. **Add more actions** based on your app needs
2. **Integrate real analytics** (Firebase, Amplitude, etc.)
3. **Use Keychain** for secure storage
4. **Add network status** monitoring
5. **Implement file uploads** (photos, documents)
6. **Add biometric auth** (Face ID, Touch ID)
7. **Create TypeScript definitions** for type safety

## Resources

- **Bridge Specification**: See `../spec.md` for complete details
- **Apple WKWebView Docs**: https://developer.apple.com/documentation/webkit/wkwebview
- **Swift Concurrency**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html

## License

This sample code is provided as-is for demonstration purposes.

## Questions?

Check the specification document (`spec.md`) for detailed information about:
- Message format
- Error handling
- Design philosophy
- Platform differences (iOS vs Android)
- Common patterns

