# Check-Mate: JavaScript Bridge Sample Apps [![Android CI](https://github.com/kibotu/check-mate/actions/workflows/android.yml/badge.svg)](https://github.com/kibotu/check-mate/actions/workflows/android.yml) [![iOS CI](https://github.com/kibotu/check-mate/actions/workflows/ios.yml/badge.svg)](https://github.com/kibotu/check-mate/actions/workflows/ios.yml)

A cross-platform JavaScript bridge implementation demonstrating **write-once, run-everywhere** web development for iOS and Android mobile apps.

## 🎯 Key Achievement

**99.5% identical HTML/JavaScript code** runs on both iOS and Android with no platform-specific code required!

```javascript
// This exact code works on both iOS and Android!
await window.bridge.ready();

const info = await window.bridge.call({
    data: { action: 'getDeviceInfo' }
});

console.log(`Running on ${info.platform}`);
```

## 📁 Repository Structure

```
check-mate/
├── android-sample/          # Android sample app (Kotlin)
│   └── app/src/main/assets/
│       └── index.html       # ⭐ Shared web code (99.5% identical)
│
├── ios-sample/              # iOS sample app (Swift)
│   └── BridgeSample/Resources/
│       └── index.html       # ⭐ Shared web code (99.5% identical)
│
└── spec.md                  # Bridge specification
```

## 🚀 Quick Start

### Android Sample
```bash
cd android-sample
./gradlew installDebug
```

### iOS Sample
```bash
cd ios-sample
open BridgeSample.xcodeproj
# Build and run in Xcode
```

## ✨ Features

Both sample apps demonstrate **identical functionality** using **identical web code**:

### 📱 Device & System
- Get device information
- Request permissions (camera, location)
- Open app settings
- Copy to clipboard
- Open URLs
- Check network status

### 💬 UI Actions
- Show toast notifications
- Show native alerts with buttons
- Set navigation title

### 💾 Storage
- Save secure data
- Load secure data
- Remove secure data

### 📊 Analytics
- Track events (fire-and-forget)
- Track screen views
- Set user ID

### 🔄 Bidirectional Communication
- Web → Native: Request-response and fire-and-forget
- Native → Web: Events and requests

## 🎨 Bridge API

The bridge provides a simple, unified API that works identically on both platforms:

### Initialize
```javascript
await window.bridge.ready();
```

### Call Native
```javascript
// Request-response pattern
const result = await window.bridge.call({
    data: {
        action: 'getDeviceInfo'
    }
}, { timeout: 30000 });

// Fire-and-forget pattern (no await)
window.bridge.call({
    data: {
        action: 'trackEvent',
        content: { event: 'button_click' }
    }
});
```

### Handle Native Messages
```javascript
window.bridge.on(async (message) => {
    const { action, content } = message.data;
    
    if (action === 'nativeEvent') {
        console.log('Received:', content);
    }
    
    // Return response for request-response pattern
    return { result: 'data' };
});
```

## 🔍 How It Works

### Automatic Platform Detection

The bridge automatically detects the platform at runtime:

- **Android**: Uses `window.AndroidBridge.postMessage()`
- **iOS**: Uses `window.webkit.messageHandlers.bridge.postMessage()`

Web developers **never need to check the platform** - the bridge handles it transparently!

### Platform Implementations

#### Android
- **WebView**: Android WebView with `@JavascriptInterface`
- **Language**: Kotlin with Coroutines
- **Bridge File**: External `bridge.js` loaded via `<script>` tag

#### iOS
- **WebView**: WKWebView with `WKScriptMessageHandler`
- **Language**: Swift with async/await
- **Bridge File**: JavaScript injected at runtime via `WKUserScript`

## 📊 Code Identity Verification

Run this to see the difference between the two HTML files:

```bash
diff android-sample/app/src/main/assets/index.html \
     ios-sample/BridgeSample/Resources/index.html
```

Result: Only 3 lines differ (the `<script src="bridge.js">` tag on Android)

## 📚 Documentation

- **[spec.md](spec.md)** - Complete bridge specification
- **[android-sample/README.md](android-sample/README.md)** - Android implementation details
- **[ios-sample/README.md](ios-sample/README.md)** - iOS implementation details

## 🧪 Sample App Features

Both sample apps include:

- ✅ Interactive UI demonstrating all bridge features
- ✅ Real-time console output
- ✅ Device information display
- ✅ Automated test suite
- ✅ Debug mode toggle
- ✅ Native → Web demo events

## 🎯 Benefits

### For Web Developers
- ✅ Write once, deploy to iOS and Android
- ✅ Use standard JavaScript/HTML/CSS
- ✅ No platform-specific code
- ✅ Modern async/await syntax
- ✅ Promise-based API

### For Native Developers
- ✅ Clear specification to implement
- ✅ Type-safe message format
- ✅ Flexible action handlers
- ✅ Bidirectional communication
- ✅ Error handling built-in

### For Product Teams
- ✅ Faster development
- ✅ Single codebase to maintain
- ✅ Consistent UX across platforms
- ✅ Easy to onboard web developers
- ✅ Reduced bugs

## 🔧 Technical Highlights

- **Bridge Version**: 1.0.0 (identical on both platforms)
- **Message Format**: Structured JSON with action/content pattern
- **Communication**: Bidirectional (Web ↔ Native)
- **Async**: Promise-based with timeout support
- **Error Handling**: Structured error codes and messages
- **Debug Mode**: Toggle verbose logging
- **Platform Detection**: Automatic

## 📈 Statistics

- **Shared Web Code**: 99.5% identical
- **Bridge Actions**: 15 actions supported
- **Demo Features**: 7 feature categories
- **Test Cases**: 7 automated tests
- **Lines of HTML/JS**: ~635 lines (identical on both platforms)

## 🎉 Result

This project demonstrates that **true cross-platform web development** is possible with a well-designed JavaScript bridge. Web developers can write their code once and have it work identically on both iOS and Android mobile apps.

**No platform detection. No conditional code. Just clean, portable JavaScript.** 🚀

## 📝 License

See individual sample app directories for license information.

## 🤝 Contributing

Contributions welcome! This is a reference implementation of a cross-platform JavaScript bridge specification.

---

**Built to demonstrate write-once, run-everywhere web development for mobile apps.**

