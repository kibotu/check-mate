# JavaScript ↔ Native Bridge Architecture

## Overview

A robust, bidirectional communication bridge enabling seamless interaction between web content (JavaScript) and native mobile platforms (iOS/Android). The bridge provides a **unified interface** that abstracts platform differences, allowing web developers to write once and deploy across both platforms.

### Key Features

- 🌉 **Bidirectional Communication**: Web→Native and Native→Web messaging
- 🎯 **Unified API**: Single JavaScript interface works identically on iOS and Android
- 🚀 **Fire-and-Forget & Async/Await**: Flexible communication patterns for different use cases
- 🔢 **Version-Safe**: Schema versioning prevents crashes during independent deployments
- 📦 **Command-Based**: Extensible architecture makes adding features trivial
- 🔒 **Secure**: Platform security best practices (JavascriptInterface, WKScriptMessageHandler)

---

## Architecture Components

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Web Application                          │
│                         (JavaScript)                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              window.bridge (Injected JS API)                │ │
│  │  • Promise-based async/await interface                      │ │
│  │  • Timeout handling & error management                      │ │
│  │  • Request/Response correlation (ID tracking)               │ │
│  │  • Event subscription system                                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↕ JSON Messages
┌─────────────────────────────────────────────────────────────────┐
│                      Platform Abstraction                        │
│  ┌──────────────────────┐       ┌──────────────────────┐        │
│  │   Android WebView    │       │   iOS WKWebView      │        │
│  │  @JavascriptInterface│       │ WKScriptMessageHandler        │
│  └──────────────────────┘       └──────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                              ↕ Native Bridge Layer
┌─────────────────────────────────────────────────────────────────┐
│                      JavaScript Bridge                           │
│  • Message parsing & validation                                  │
│  • Schema version checking                                       │
│  • Request/Response routing                                      │
│  • Error handling & recovery                                     │
│  • Coroutine/Async dispatch                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↕ Command Pattern
┌─────────────────────────────────────────────────────────────────┐
│                   Command Handler Registry                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐ │
│  │  Device    │  │     UI     │  │ Navigation │  │ Analytics │ │
│  │  Commands  │  │  Commands  │  │  Commands  │  │ Commands  │ │
│  └────────────┘  └────────────┘  └────────────┘  └───────────┘ │
│  • DeviceInfo  • ShowToast      • Navigate      • TrackEvent   │
│  • NetworkState • ShowAlert     • TopNav        • TrackScreen  │
│  • OpenSettings • Haptic        • BottomNav                    │
│                                  • SystemBars                   │
└─────────────────────────────────────────────────────────────────┘
                              ↕ Native APIs
┌─────────────────────────────────────────────────────────────────┐
│                       Native Platform                            │
│  Android APIs / iOS APIs / System Services / Hardware           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Message Protocol

### Message Format

All messages follow a standardized JSON structure:

```json
{
  "id": "msg_1234567890_1_abc123xyz",    // Unique ID for request/response correlation
  "version": 1,                            // Schema version (auto-attached by bridge)
  "data": {
    "action": "deviceInfo",                // Command identifier
    "content": {                           // Optional command parameters
      "key": "value"
    }
  }
}
```

### Web → Native Flow

```javascript
// JavaScript sends:
await window.bridge.call({
  data: { action: 'showToast', content: { message: 'Hello!' } }
});

// Bridge transforms to:
{
  "id": "msg_1698765432_42_xyz",
  "version": 1,
  "data": { "action": "showToast", "content": { "message": "Hello!" } }
}

// Native responds:
{
  "id": "msg_1698765432_42_xyz",
  "data": { "success": true }
}

// JavaScript receives resolved Promise
```

### Native → Web Flow

```kotlin
// Android: Native sends event
javaScriptBridge.sendToWeb(
    action = "lifecycle",
    content = mapOf("event" to "focused")
)

// JavaScript receives:
window.bridge.on((message) => {
  const { action, content } = message.data;
  // action: "lifecycle", content: { event: "focused" }
});
```

---

## Sequence Diagrams

### 1. Refresh Command (Web→Native→Web)

```
┌──────┐                    ┌──────────┐                    ┌─────────┐                  ┌──────────┐
│ Web  │                    │  Bridge  │                    │ Handler │                  │  Native  │
│(JS)  │                    │  Layer   │                    │Registry │                  │ Services │
└──────┘                    └──────────┘                    └─────────┘                  └──────────┘
   │                              │                              │                             │
   │  bridge.call({              │                              │                             │
   │    action: 'refresh'        │                              │                             │
   │  }) ─────────────────────────>                             │                             │
   │                              │                              │                             │
   │                              │ Parse & Validate JSON        │                             │
   │                              │ Check schema version         │                             │
   │                              │ Extract action="refresh"     │                             │
   │                              │                              │                             │
   │                              │ dispatch(action, content) ──>│                             │
   │                              │                              │                             │
   │                              │                              │ Find RefreshCommand         │
   │                              │                              │ command.handle(content)     │
   │                              │                              │ ─────────────────────────> │
   │                              │                              │                             │
   │                              │                              │                    Trigger  │
   │                              │                              │                    refresh  │
   │                              │                              │                    service  │
   │                              │                              │                             │
   │                              │                              │ <────────────────────────── │
   │                              │                              │    { success: true }        │
   │                              │                              │                             │
   │                              │ <─────────────────────────── │                             │
   │                              │    return result             │                             │
   │                              │                              │                             │
   │                              │ sendResponseToWeb(id, data)  │                             │
   │                              │ Execute JS callback          │                             │
   │  <──────────────────────────                                │                             │
   │  Promise resolves                                           │                             │
   │                              │                              │                             │
```

**Key Points:**
- Web awaits the Promise, blocking code execution until native responds
- Bridge uses message ID to correlate request with response
- Command pattern isolates business logic from bridge infrastructure
- Response flows back through the same path

---

### 2. Lifecycle Events (Native→Web Push)

```
┌──────────┐              ┌──────────┐              ┌──────┐
│ Native   │              │  Bridge  │              │ Web  │
│Fragment  │              │  Layer   │              │ (JS) │
└──────────┘              └──────────┘              └──────┘
     │                          │                        │
     │ onResume() called        │                        │
     │ Screen gains focus       │                        │
     │                          │                        │
     │ sendToWeb(               │                        │
     │   "lifecycle",           │                        │
     │   { event: "focused" }   │                        │
     │ ) ─────────────────────> │                        │
     │                          │                        │
     │                          │ buildMessage()         │
     │                          │ {                      │
     │                          │   data: {              │
     │                          │     action: "lifecycle"│
     │                          │     content: {         │
     │                          │       event: "focused" │
     │                          │     }                  │
     │                          │   }                    │
     │                          │ }                      │
     │                          │                        │
     │                          │ evaluateJavascript(    │
     │                          │   "window.bridge._handleNativeMessage(...)"
     │                          │ ) ──────────────────────> 
     │                          │                        │
     │                          │                        │ bridge._handleNativeMessage()
     │                          │                        │ triggers registered handler
     │                          │                        │
     │                          │                        │ window.bridge.on((msg) => {
     │                          │                        │   // Handle lifecycle event
     │                          │                        │   refreshData();
     │                          │                        │ })
     │                          │                        │
     │                          │                        │ [Optional] return response
     │                          │ <────────────────────── │
     │                          │                        │
     │ [Optional] callback      │                        │
     │ invoked                  │                        │
     │ <─────────────────────── │                        │
     │                          │                        │
```

**Key Points:**
- Fire-and-forget pattern: native doesn't wait for web response
- Web registers ONE handler for ALL native→web events
- Handler routes events based on `action` field
- No blocking on native side - events pushed asynchronously

---

### 3. Fire-and-Forget (Analytics)

```
┌──────┐                    ┌──────────┐                    ┌─────────┐
│ Web  │                    │  Bridge  │                    │ Handler │
│(JS)  │                    │  Layer   │                    │Registry │
└──────┘                    └──────────┘                    └─────────┘
   │                              │                              │
   │  bridge.call({              │                              │
   │    action: 'trackEvent',    │                              │
   │    content: {...}           │                              │
   │  })  [NO await]             │                              │
   │  ─────────────────────────> │                              │
   │                              │                              │
   │  Promise returned            │                              │
   │  (but not awaited)           │                              │
   │ <───────────────────────────│                              │
   │                              │                              │
   │  Continue execution          │ Parse message                │
   │  immediately                 │ ──────────────────────────> │
   │                              │                              │
   │                              │                              │ Track event
   │                              │                              │ (async)
   │                              │                              │
   │                              │ <────────────────────────── │
   │                              │ returns null                 │
   │                              │ (no response needed)         │
   │                              │                              │
   │  [Promise resolves           │                              │
   │   but nobody waits]          │                              │
   │                              │                              │
```

**Key Points:**
- No `await` used - web continues immediately
- Command returns `null` - no response sent to web
- Zero user-perceived latency
- Suitable for analytics, haptics, logging

---

## Platform Implementations

### Android Implementation

#### JavaScriptBridge.kt

```kotlin
class JavaScriptBridge(
    private val webView: WebView,
    private val messageHandler: BridgeMessageHandler
) {
    companion object {
        const val BRIDGE_NAME = "Bridge"       // window.Bridge in JavaScript
        const val SCHEMA_VERSION = 1           // Current schema version
    }

    @JavascriptInterface
    fun postMessage(message: String) {
        scope.launch {
            // 1. Parse JSON message
            val messageObj = JSONObject(message)
            val id = messageObj.optString("id")
            val data = messageObj.optJSONObject("data")
            
            // 2. Version check - silently ignore future versions
            val requestedVersion = data.optInt("version", SCHEMA_VERSION)
            if (requestedVersion > SCHEMA_VERSION) {
                return@launch  // Graceful degradation
            }
            
            // 3. Extract action & content
            val action = data.optString("action")
            val content = data.opt("content")
            
            // 4. Dispatch to command handler
            val result = messageHandler.handle(action, content)
            
            // 5. Send response if request had ID
            if (!id.isNullOrEmpty()) {
                sendResponseToWeb(id, result)
            }
        }
    }
    
    fun sendToWeb(action: String, content: Any? = null) {
        val message = buildMessage(null, action, content)
        val script = "window.bridge && window.bridge._handleNativeMessage($message)"
        webView.evaluateJavascript(script, null)
    }
}
```

**Key Design Decisions:**
- `@JavascriptInterface` required by Android security model
- Coroutines prevent ANR (Application Not Responding) during slow operations
- Silent version mismatch handling enables progressive enhancement
- Optional response pattern supports both fire-and-forget and async/await

#### Command Pattern (Strategy Pattern)

```kotlin
interface BridgeCommand {
    val action: String                        // e.g., "deviceInfo"
    suspend fun handle(content: Any?): Any?   // Returns data or null
}

class DeviceInfoCommand : BridgeCommand {
    override val action = "deviceInfo"
    
    override suspend fun handle(content: Any?): JSONObject {
        return JSONObject().apply {
            put("platform", "Android")
            put("osVersion", Build.VERSION.RELEASE)
            put("manufacturer", Build.MANUFACTURER)
            put("model", Build.MODEL)
        }
    }
}

class DefaultBridgeMessageHandler : BridgeMessageHandler {
    private val commands = listOf(
        DeviceInfoCommand(),
        ShowToastCommand(),
        NavigationCommand(),
        RefreshCommand(),
        // ... ~20 commands
    )
    
    override suspend fun handle(action: String, content: Any?): Any? {
        val command = commands.find { it.action == action }
        return command?.handle(content) 
            ?: createErrorResponse("UNKNOWN_ACTION")
    }
}
```

**Benefits:**
- ✅ Adding new commands is trivial (implement interface, add to list)
- ✅ Each command is isolated and testable
- ✅ No coupling between commands
- ✅ Commands can be reused across different bridge implementations

---

### iOS Implementation

While the iOS implementation is in a separate repository, it follows the same architecture:

```swift
// Conceptual iOS structure (WKWebView)

class JavaScriptBridge {
    private let webView: WKWebView
    private let messageHandler: BridgeMessageHandler
    
    func postMessage(message: [String: Any]) {
        // 1. Parse message dictionary
        // 2. Version check
        // 3. Extract action & content
        // 4. Dispatch to command handler
        // 5. Send response via evaluateJavaScript
    }
    
    func sendToWeb(action: String, content: Any?) {
        let script = """
            window.bridge && window.bridge._handleNativeMessage({
                data: { action: '\(action)', content: \(content) }
            })
        """
        webView.evaluateJavaScript(script)
    }
}

// WKScriptMessageHandler protocol for receiving messages from JS
```

**Key Differences from Android:**
- Uses `WKScriptMessageHandler` instead of `@JavascriptInterface`
- Swift async/await instead of Kotlin coroutines
- Otherwise identical architecture and message protocol

---

## Unified JavaScript Layer

### The Magic: Platform-Agnostic API

The **injected JavaScript bridge** is what makes the API unified. It's the same code on both platforms:

```javascript
(function() {
    'use strict';
    
    const SCHEMA_VERSION = 1;  // Injected from native
    const pendingPromises = new Map();
    
    const bridge = {
        schemaVersion: SCHEMA_VERSION,
        
        // Main async/await interface
        call(message, options = {}) {
            return new Promise((resolve, reject) => {
                const id = generateId();
                const timeout = options.timeout ?? 30000;
                
                // Set up timeout
                const timeoutId = setTimeout(() => {
                    pendingPromises.delete(id);
                    reject(new Error(`Request timeout after ${timeout}ms`));
                }, timeout);
                
                // Store promise handlers
                pendingPromises.set(id, {
                    resolve: (data) => {
                        clearTimeout(timeoutId);
                        pendingPromises.delete(id);
                        resolve(data);
                    },
                    reject: (error) => {
                        clearTimeout(timeoutId);
                        pendingPromises.delete(id);
                        reject(error);
                    }
                });
                
                // Send to native (platform-specific interface)
                const fullMessage = {
                    version: SCHEMA_VERSION,
                    id,
                    data: message.data
                };
                
                // Android: window.Bridge.postMessage(JSON.stringify(fullMessage))
                // iOS: window.webkit.messageHandlers.Bridge.postMessage(fullMessage)
                window.Bridge.postMessage(JSON.stringify(fullMessage));
            });
        },
        
        // Event subscription
        on(handler) {
            messageHandler = handler;
        },
        
        // Internal: Called by native to resolve promises
        _handleNativeResponse(response) {
            const promise = pendingPromises.get(response.id);
            if (!promise) return;
            
            if (response.error) {
                promise.reject(new Error(response.error.message));
            } else {
                promise.resolve(response.data);
            }
        },
        
        // Internal: Called by native to send events
        _handleNativeMessage(message) {
            if (messageHandler) {
                messageHandler(message);
            }
        }
    };
    
    // Freeze and expose
    Object.defineProperty(window, 'bridge', {
        value: Object.freeze(bridge),
        writable: false,
        configurable: false
    });
})();
```

**Why This Works:**

1. **Same API surface**: Web developers call `window.bridge.call()` on both platforms
2. **Platform detection inside**: The JS layer adapts to platform-specific native interfaces
3. **Promise abstraction**: Hides complexity of request/response correlation
4. **Timeout protection**: Prevents hanging on unresponsive native code
5. **Type safety**: Consistent JSON contracts across platforms

---

## Fire-and-Forget vs Async/Await

### Fire-and-Forget Pattern

**Use Cases:**
- Analytics events
- Haptic feedback
- Logging
- Non-critical operations

**Example:**
```javascript
// No await - fire and forget
bridge.call({
    data: { action: 'trackEvent', content: { event: 'page_view' } }
});
// Execution continues immediately
```

**Implementation:**
```kotlin
class TrackEventCommand : BridgeCommand {
    override suspend fun handle(content: Any?): JSONObject? {
        // Track event asynchronously
        Tracker.trackEvent(...)
        
        // Return null = no response sent to web
        return null
    }
}
```

**Benefits:**
- ✅ Zero user-perceived latency
- ✅ Doesn't block UI thread
- ✅ Suitable for observability/telemetry

---

### Async/Await Pattern

**Use Cases:**
- Device info queries
- Navigation with confirmation
- Secure storage operations
- Any operation needing result

**Example:**
```javascript
// Await response
try {
    const info = await bridge.call(
        { data: { action: 'deviceInfo' } },
        { timeout: 5000 }
    );
    console.log('Running on:', info.platform);
} catch (error) {
    console.error('Failed:', error.message);
}
```

**Implementation:**
```kotlin
class DeviceInfoCommand : BridgeCommand {
    override suspend fun handle(content: Any?): JSONObject {
        return JSONObject().apply {
            put("platform", "Android")
            put("model", Build.MODEL)
        }
    }
}
```

**Benefits:**
- ✅ Web code can react to results
- ✅ Error handling via try/catch
- ✅ Synchronous-style programming

---

## Schema Versioning

### Why Versioning Matters

**Problem:** Web and native apps deploy independently
- Web update may use new features not in old native app
- Native update may deprecate features web still uses
- Need graceful degradation, not crashes

**Solution:** Simple integer versioning with forward compatibility

### Version Check Flow

```
Web sends:           Native receives:         Native action:
─────────────────    ──────────────────       ─────────────────────────
version: 1           SCHEMA_VERSION: 1        ✅ Process (same version)

version: 1           SCHEMA_VERSION: 2        ✅ Process (backward compat)

version: 2           SCHEMA_VERSION: 1        ⚠️  Silently ignore (future version)
                                              Web times out → fallback
```

### Implementation

```kotlin
// Android
@JavascriptInterface
fun postMessage(message: String) {
    val requestedVersion = data.optInt("version", SCHEMA_VERSION)
    if (requestedVersion > SCHEMA_VERSION) {
        ProfiLogger.w("Ignoring future version $requestedVersion")
        return  // Silent ignore - web will timeout
    }
    // Process message...
}
```

```javascript
// Web - version gating
const version = window.bridge.schemaVersion;

if (version >= 2) {
    // Use new feature from v2
    await bridge.call({ data: { action: 'newFeatureV2' } });
} else {
    // Fallback for v1
    console.log('Feature not available, using alternative');
}
```

### Versioning Strategy

**When to increment:**
- ✅ Breaking change to message format
- ✅ Removing a command
- ✅ Changing command behavior in incompatible way

**When NOT to increment:**
- ✅ Adding new commands (old web ignores them)
- ✅ Adding optional fields to existing commands
- ✅ Bug fixes that don't change API

**Example - Adding Optional Field (No version bump):**
```javascript
// v1 command
{ action: 'showToast', content: { message: 'Hi' } }

// v1 with new optional field (still v1!)
{ action: 'showToast', content: { message: 'Hi', duration: 'long' } }
```

---

## Example Command: Adding New Feature

Let's walk through adding a `vibrate` command to demonstrate extensibility:

### 1. Define Command Interface

```kotlin
// Android: HapticCommand.kt
class HapticCommand : BridgeCommand {
    
    override val action = "haptic"
    
    override suspend fun handle(content: Any?): JSONObject? = withContext(Dispatchers.Main) {
        try {
            // Parse vibrate parameter
            val shouldVibrate = BridgeParsingUtils.parseBoolean(content, "vibrate")
            
            if (shouldVibrate) {
                // Get vibrator service
                val context = ActivityProvider.currentActivity ?: application
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                
                // Trigger haptic feedback
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(
                        VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(50)
                }
            }
            
            // Fire-and-forget: return null (no response needed)
            null
            
        } catch (e: Exception) {
            ProfiLogger.e("[HapticCommand] Error", e)
            // Even errors are fire-and-forget for haptics
            null
        }
    }
}
```

### 2. Register Command

```kotlin
// Android: DefaultBridgeMessageHandler.kt
class DefaultBridgeMessageHandler : BridgeMessageHandler {
    private val commands = listOf(
        DeviceInfoCommand(),
        ShowToastCommand(),
        // ... existing commands ...
        HapticCommand()  // ← Add here
    )
}
```

### 3. Document for Web Developers

```markdown
### `haptic`

Triggers haptic/vibration feedback.

**Usage:**
```javascript
await bridge.call({
  data: {
    action: 'haptic',
    content: { vibrate: true }
  }
});
```

**Parameters:**
- `content.vibrate` (boolean, required): Whether to vibrate
```

### That's It!

**What we didn't need to touch:**
- ❌ Bridge infrastructure (`JavaScriptBridge.kt`)
- ❌ Message parsing/routing logic
- ❌ JavaScript API (`window.bridge`)
- ❌ iOS implementation (implements same interface)

**Benefits of this approach:**
- ✅ 3 files touched (command, handler, docs)
- ✅ ~50 lines of code
- ✅ Fully isolated from other commands
- ✅ Testable in isolation
- ✅ Works on both platforms with same API

---

## Lifecycle Events Deep Dive

### Implementation

```kotlin
// Android: PluginWebFragment.kt
override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    
    val event = if (hasFocus) "focused" else "defocused"
    
    sendToWeb(
        action = "lifecycle",
        content = mapOf("event" to event)
    )
}
```

### Web Usage

```javascript
// 1. Subscribe to lifecycle events
window.bridge.on((message) => {
    const { action, content } = message.data || {};
    
    if (action === 'lifecycle') {
        if (content?.event === 'focused') {
            console.log('Screen gained focus');
            refreshData();      // Refresh data when user returns
            resumeAnimations(); // Resume paused work
        } else if (content?.event === 'defocused') {
            console.log('Screen lost focus');
            pauseAnimations();  // Save battery
            saveState();        // Persist state
        }
    }
});
```

### Common Use Cases

**Focused Event:**
- Refresh data from server
- Resume animations/videos
- Re-establish WebSocket connections
- Restart timers

**Defocused Event:**
- Pause media playback
- Save form state
- Close WebSocket connections
- Stop polling

---

## Recommendations for Web Developers

### 1. Unified Abstraction Layer 🎯

**What it is:**  
The JavaScript layer abstracts platform differences. Web developers never need to know if they're on Android or iOS.

**Why it matters:**
```javascript
// ✅ Write once, works everywhere
await window.bridge.call({ data: { action: 'deviceInfo' } });

// ❌ Instead of platform-specific code:
if (isAndroid) {
    window.Android.getDeviceInfo();
} else if (isIOS) {
    window.webkit.messageHandlers.getDeviceInfo.postMessage({});
}
```

**Best Practice:**
- Use `window.bridge.schemaVersion` for capability detection
- Never check platform directly in web code
- Let the bridge handle platform differences

---

### 2. Promise-Based Modern API 🚀

**What it is:**  
Async/await syntax instead of callbacks.

**Why it matters:**
```javascript
// ✅ Modern, readable
try {
    const info = await bridge.call({ data: { action: 'deviceInfo' } });
    const status = await bridge.call({ data: { action: 'networkState' } });
    displayDashboard(info, status);
} catch (error) {
    showError(error.message);
}

// ❌ Callback hell alternative:
getDeviceInfo(function(info) {
    getNetworkState(function(status) {
        displayDashboard(info, status);
    }, function(error) {
        showError(error);
    });
}, function(error) {
    showError(error);
});
```

---

### 3. Fire-and-Forget for Performance 🏎️

**What it is:**  
Don't await operations that don't need responses.

**Why it matters:**
```javascript
// ✅ Fire and forget - zero latency
function trackButtonClick(button) {
    bridge.call({
        data: { action: 'trackEvent', content: { event: 'click', button } }
    });
    // Continues immediately - user sees instant response
    navigateToPage();
}

// ❌ Unnecessary await adds latency
async function trackButtonClick(button) {
    await bridge.call({
        data: { action: 'trackEvent', content: { event: 'click', button } }
    });
    // User waits ~50ms for tracking before navigation
    navigateToPage();
}
```

**Use fire-and-forget for:**
- Analytics events
- Logging
- Haptic feedback
- Non-critical operations

---

### 4. Command-Based Extensibility 📦

**What it is:**  
The API doesn't change when adding features. Only the `action` changes.

**Why it matters:**
```javascript
// Same call pattern for ALL features:
await bridge.call({ data: { action: 'ACTION_NAME', content: {...} } });

// Examples:
await bridge.call({ data: { action: 'deviceInfo' } });
await bridge.call({ data: { action: 'showToast', content: { message: 'Hi' } } });
await bridge.call({ data: { action: 'navigate', content: { url: '...' } } });
await bridge.call({ data: { action: 'haptic', content: { vibrate: true } } });
```

**Benefits:**
- ✅ Learn one pattern, use everywhere
- ✅ Adding features doesn't break existing code
- ✅ Easy to extend (just add new action)
- ✅ Consistent error handling

---

### 5. Version-Safe Progressive Enhancement 🔢

**What it is:**  
Check version before using new features, provide fallbacks.

**Why it matters:**
```javascript
// ✅ Graceful degradation
const version = window.bridge.schemaVersion;

if (version >= 2) {
    // Use new feature from schema v2
    await bridge.call({ data: { action: 'advancedFeature' } });
} else {
    // Fallback for older versions
    console.log('Feature unavailable, using alternative');
    useBasicFeature();
}

// ❌ Crash on older apps:
await bridge.call({ data: { action: 'advancedFeature' } });
// Times out on old native versions → bad UX
```

---

### 6. Timeout Handling for Reliability ⏱️

**What it is:**  
Always set reasonable timeouts and handle failures.

**Why it matters:**
```javascript
// ✅ Timeout prevents hanging
try {
    const info = await bridge.call(
        { data: { action: 'deviceInfo' } },
        { timeout: 5000 }  // 5 second timeout
    );
    displayInfo(info);
} catch (error) {
    if (error.message.includes('timeout')) {
        console.warn('Native not responding, using defaults');
        displayInfo(DEFAULT_INFO);
    } else {
        showError(error.message);
    }
}

// ❌ No timeout - user waits 30 seconds on failure
const info = await bridge.call({ data: { action: 'deviceInfo' } });
```

**Recommended timeouts:**
- Quick operations (device info, network status): 3-5 seconds
- UI operations (toasts, alerts): 5-10 seconds
- Heavy operations (file operations): 15-30 seconds
- Analytics (fire-and-forget): No await needed

---

### 7. Single Event Handler Pattern 📡

**What it is:**  
Register ONE handler for all native→web events.

**Why it matters:**
```javascript
// ✅ Single handler, route by action
window.bridge.on((message) => {
    const { action, content } = message.data || {};
    
    switch (action) {
        case 'lifecycle':
            handleLifecycle(content);
            break;
        case 'onPushNotification':
            handlePush(content);
            break;
        case 'networkChanged':
            handleNetwork(content);
            break;
        default:
            console.log('Unknown action:', action);
    }
});

// ❌ Multiple subscriptions can cause issues
window.bridge.on(handleLifecycle);  // Don't do this
window.bridge.on(handlePush);       // Multiple handlers
window.bridge.on(handleNetwork);    // Overwrites previous
```

---

### 8. Type Safety with TypeScript 🔒

**Recommendation:**  
Define TypeScript types for bridge messages.

```typescript
// Define message types
interface BridgeMessage {
    data: {
        action: string;
        content?: unknown;
    };
}

interface BridgeOptions {
    timeout?: number;
}

interface DeviceInfo {
    platform: 'iOS' | 'Android';
    osVersion: string;
    manufacturer: string;
    model: string;
    appVersion: string;
}

// Type-safe bridge interface
interface Bridge {
    schemaVersion: number;
    ready(): Promise<void>;
    setDebug(enabled: boolean): void;
    call<T = unknown>(message: BridgeMessage, options?: BridgeOptions): Promise<T>;
    on(handler: (message: BridgeMessage) => void | Promise<void>): void;
}

// Usage with type safety
declare global {
    interface Window {
        bridge: Bridge;
    }
}

// Type-safe calls
const info = await window.bridge.call<DeviceInfo>({
    data: { action: 'deviceInfo' }
});

console.log(info.platform); // TypeScript knows this is 'iOS' | 'Android'
```

---

### 9. Error Handling Best Practices ⚠️

```javascript
// ✅ Comprehensive error handling
async function safeDeviceInfo() {
    try {
        const info = await window.bridge.call(
            { data: { action: 'deviceInfo' } },
            { timeout: 5000 }
        );
        return info;
    } catch (error) {
        // Log error for debugging
        console.error('Bridge error:', error);
        
        // Track error for monitoring
        analytics.trackError('bridge_device_info_failed', { error: error.message });
        
        // Provide fallback
        return {
            platform: 'unknown',
            model: 'unknown',
            osVersion: 'unknown'
        };
    }
}
```

---

### 10. Performance Optimization 🚄

**Batch Operations:**
```javascript
// ✅ Parallel requests
const [info, network, storage] = await Promise.all([
    bridge.call({ data: { action: 'deviceInfo' } }),
    bridge.call({ data: { action: 'networkState' } }),
    bridge.call({ data: { action: 'loadSecureData', content: { key: 'token' } } })
]);

// ❌ Sequential - 3x slower
const info = await bridge.call({ data: { action: 'deviceInfo' } });
const network = await bridge.call({ data: { action: 'networkState' } });
const storage = await bridge.call({ data: { action: 'loadSecureData' } });
```

**Cache Results:**
```javascript
// Cache device info (doesn't change during session)
let cachedDeviceInfo = null;

async function getDeviceInfo() {
    if (!cachedDeviceInfo) {
        cachedDeviceInfo = await bridge.call({ data: { action: 'deviceInfo' } });
    }
    return cachedDeviceInfo;
}
```

---

## Testing

### Unit Testing Commands (Android)

```kotlin
class DeviceInfoCommandTest {
    @Test
    fun `deviceInfo returns expected fields`() = runBlocking {
        val command = DeviceInfoCommand()
        val result = command.handle(null) as JSONObject
        
        assertEquals("Android", result.getString("platform"))
        assertNotNull(result.getString("osVersion"))
        assertNotNull(result.getString("model"))
    }
}
```

### Integration Testing Bridge

```kotlin
class JavaScriptBridgeTest {
    @Test
    fun `postMessage with valid action returns response`() = runBlocking {
        val handler = mock(BridgeMessageHandler::class.java)
        val bridge = JavaScriptBridge(webView, handler)
        
        val message = """
            {
                "id": "test_123",
                "data": { "action": "deviceInfo" }
            }
        """.trimIndent()
        
        bridge.postMessage(message)
        
        verify(handler).handle("deviceInfo", null)
    }
}
```

### E2E Testing from Web

```javascript
describe('Bridge', () => {
    beforeAll(async () => {
        await window.bridge.ready();
    });

    it('should get device info', async () => {
        const info = await window.bridge.call({
            data: { action: 'deviceInfo' }
        });
        
        expect(info.platform).toMatch(/iOS|Android/);
        expect(info.model).toBeDefined();
    });

    it('should handle unknown action', async () => {
        await expect(
            window.bridge.call({ data: { action: 'unknownAction' } })
        ).rejects.toThrow('UNKNOWN_ACTION');
    });

    it('should timeout on long operations', async () => {
        await expect(
            window.bridge.call(
                { data: { action: 'slowOperation' } },
                { timeout: 1000 }
            )
        ).rejects.toThrow('timeout');
    });
});
```

---

## Security Considerations

### 1. JavaScript Injection Protection

**Android:**
```kotlin
// ✅ Only methods with @JavascriptInterface are exposed
@JavascriptInterface
fun postMessage(message: String) { ... }

// ❌ Without annotation, not accessible from JavaScript
fun internalMethod() { ... }
```

**Web:**
```javascript
// Bridge is frozen - cannot be modified by web code
Object.defineProperty(window, 'bridge', {
    value: Object.freeze(bridge),
    writable: false,
    configurable: false
});
```

### 2. Message Validation

```kotlin
@JavascriptInterface
fun postMessage(message: String) {
    try {
        val messageObj = JSONObject(message)
        
        // Validate required fields
        require(messageObj.has("data")) { "Missing data field" }
        
        val data = messageObj.getJSONObject("data")
        require(data.has("action")) { "Missing action field" }
        
        // Validate action is not malicious
        val action = data.getString("action")
        require(action.matches(Regex("^[a-zA-Z0-9_]+$"))) {
            "Invalid action format"
        }
        
    } catch (e: Exception) {
        sendErrorToWeb(null, "INVALID_MESSAGE", e.message)
    }
}
```

### 3. Content Security Policy (CSP)

Ensure WebView has appropriate CSP headers to prevent XSS attacks.

---

## Performance Characteristics

### Latency Measurements

| Operation | Typical Latency | Notes |
|-----------|----------------|-------|
| Fire-and-forget | < 1ms | No network round-trip |
| Device info query | 5-15ms | Simple data retrieval |
| UI operations (toast) | 10-30ms | Requires main thread |
| Secure storage | 20-50ms | Encryption overhead |
| Network operations | 100-1000ms+ | Depends on network |

### Optimization Tips

1. **Batch requests**: Use `Promise.all()` for parallel operations
2. **Cache results**: Device info doesn't change during session
3. **Fire-and-forget**: Don't await analytics/logging
4. **Lazy initialization**: Don't call bridge during page load unless needed
5. **Debounce**: For frequent calls (scroll events), debounce before calling native

---

## Troubleshooting

### Common Issues

**1. Bridge not available**
```javascript
// ✅ Always check bridge is ready
await window.bridge.ready();

// ❌ Calling before bridge initialized
window.bridge.call(...); // Error: bridge is undefined
```

**2. Timeout errors**
```javascript
// Increase timeout for slow operations
await bridge.call(
    { data: { action: 'slowOperation' } },
    { timeout: 30000 }  // 30 seconds
);
```

**3. Version mismatch**
```javascript
// Check version and provide fallback
if (window.bridge.schemaVersion >= 2) {
    // Use new feature
} else {
    // Use old approach or show error
}
```

**4. Events not received**
```javascript
// Register handler BEFORE sending commands
window.bridge.on(handler);

// Then make calls
await bridge.call({ data: { action: 'lifecycleEvents', content: { enable: true } } });
```

---

## Complete Example: Dashboard Screen

```javascript
/**
 * Dashboard screen demonstrating bridge best practices
 */

class Dashboard {
    constructor() {
        this.deviceInfo = null;
        this.initialized = false;
    }

    async init() {
        try {
            // 1. Wait for bridge# JavaScript ↔ Native Bridge Architecture

## Overview

A robust, bidirectional communication bridge enabling seamless interaction between web content (JavaScript) and native mobile platforms (iOS/Android). The bridge provides a **unified interface** that abstracts platform differences, allowing web developers to write once and deploy across both platforms.

### Key Features

- 🌉 **Bidirectional Communication**: Web→Native and Native→Web messaging
- 🎯 **Unified API**: Single JavaScript interface works identically on iOS and Android
- 🚀 **Fire-and-Forget & Async/Await**: Flexible communication patterns for different use cases
- 🔢 **Version-Safe**: Schema versioning prevents crashes during independent deployments
- 📦 **Command-Based**: Extensible architecture makes adding features trivial
- 🔒 **Secure**: Platform security best practices (JavascriptInterface, WKScriptMessageHandler)

---

## Architecture Components

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Web Application                          │
│                         (JavaScript)                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              window.bridge (Injected JS API)                │ │
│  │  • Promise-based async/await interface                      │ │
│  │  • Timeout handling & error management                      │ │
│  │  • Request/Response correlation (ID tracking)               │ │
│  │  • Event subscription system                                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
↕ JSON Messages
┌─────────────────────────────────────────────────────────────────┐
│                      Platform Abstraction                        │
│  ┌──────────────────────┐       ┌──────────────────────┐        │
│  │   Android WebView    │       │   iOS WKWebView      │        │
│  │  @JavascriptInterface│       │ WKScriptMessageHandler        │
│  └──────────────────────┘       └──────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
↕ Native Bridge Layer
┌─────────────────────────────────────────────────────────────────┐
│                      JavaScript Bridge                           │
│  • Message parsing & validation                                  │
│  • Schema version checking                                       │
│  • Request/Response routing                                      │
│  • Error handling & recovery                                     │
│  • Coroutine/Async dispatch                                      │
└─────────────────────────────────────────────────────────────────┘
↕ Command Pattern
┌─────────────────────────────────────────────────────────────────┐
│                   Command Handler Registry                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐ │
│  │  Device    │  │     UI     │  │ Navigation │  │ Analytics │ │
│  │  Commands  │  │  Commands  │  │  Commands  │  │ Commands  │ │
│  └────────────┘  └────────────┘  └────────────┘  └───────────┘ │
│  • DeviceInfo  • ShowToast      • Navigate      • TrackEvent   │
│  • NetworkState • ShowAlert     • TopNav        • TrackScreen  │
│  • OpenSettings • Haptic        • BottomNav                    │
│                                  • SystemBars                   │
└─────────────────────────────────────────────────────────────────┘
↕ Native APIs
┌─────────────────────────────────────────────────────────────────┐
│                       Native Platform                            │
│  Android APIs / iOS APIs / System Services / Hardware           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Message Protocol

### Message Format

All messages follow a standardized JSON structure:

```json
{
  "id": "msg_1234567890_1_abc123xyz",    // Unique ID for request/response correlation
  "version": 1,                            // Schema version (auto-attached by bridge)
  "data": {
    "action": "deviceInfo",                // Command identifier
    "content": {                           // Optional command parameters
      "key": "value"
    }
  }
}
```

### Web → Native Flow

```javascript
// JavaScript sends:
await window.bridge.call({
  data: { action: 'showToast', content: { message: 'Hello!' } }
});

// Bridge transforms to:
{
  "id": "msg_1698765432_42_xyz",
  "version": 1,
  "data": { "action": "showToast", "content": { "message": "Hello!" } }
}

// Native responds:
{
  "id": "msg_1698765432_42_xyz",
  "data": { "success": true }
}

// JavaScript receives resolved Promise
```

### Native → Web Flow

```kotlin
// Android: Native sends event
javaScriptBridge.sendToWeb(
    action = "lifecycle",
    content = mapOf("event" to "focused")
)

// JavaScript receives:
window.bridge.on((message) => {
  const { action, content } = message.data;
  // action: "lifecycle", content: { event: "focused" }
});
```

---

## Sequence Diagrams

### 1. Refresh Command (Web→Native→Web)

```
┌──────┐                    ┌──────────┐                    ┌─────────┐                  ┌──────────┐
│ Web  │                    │  Bridge  │                    │ Handler │                  │  Native  │
│(JS)  │                    │  Layer   │                    │Registry │                  │ Services │
└──────┘                    └──────────┘                    └─────────┘                  └──────────┘
   │                              │                              │                             │
   │  bridge.call({              │                              │                             │
   │    action: 'refresh'        │                              │                             │
   │  }) ─────────────────────────>                             │                             │
   │                              │                              │                             │
   │                              │ Parse & Validate JSON        │                             │
   │                              │ Check schema version         │                             │
   │                              │ Extract action="refresh"     │                             │
   │                              │                              │                             │
   │                              │ dispatch(action, content) ──>│                             │
   │                              │                              │                             │
   │                              │                              │ Find RefreshCommand         │
   │                              │                              │ command.handle(content)     │
   │                              │                              │ ─────────────────────────> │
   │                              │                              │                             │
   │                              │                              │                    Trigger  │
   │                              │                              │                    refresh  │
   │                              │                              │                    service  │
   │                              │                              │                             │
   │                              │                              │ <────────────────────────── │
   │                              │                              │    { success: true }        │
   │                              │                              │                             │
   │                              │ <─────────────────────────── │                             │
   │                              │    return result             │                             │
   │                              │                              │                             │
   │                              │ sendResponseToWeb(id, data)  │                             │
   │                              │ Execute JS callback          │                             │
   │  <──────────────────────────                                │                             │
   │  Promise resolves                                           │                             │
   │                              │                              │                             │
```

**Key Points:**
- Web awaits the Promise, blocking code execution until native responds
- Bridge uses message ID to correlate request with response
- Command pattern isolates business logic from bridge infrastructure
- Response flows back through the same path

---

### 2. Lifecycle Events (Native→Web Push)

```
┌──────────┐              ┌──────────┐              ┌──────┐
│ Native   │              │  Bridge  │              │ Web  │
│Fragment  │              │  Layer   │              │ (JS) │
└──────────┘              └──────────┘              └──────┘
     │                          │                        │
     │ onResume() called        │                        │
     │ Screen gains focus       │                        │
     │                          │                        │
     │ sendToWeb(               │                        │
     │   "lifecycle",           │                        │
     │   { event: "focused" }   │                        │
     │ ) ─────────────────────> │                        │
     │                          │                        │
     │                          │ buildMessage()         │
     │                          │ {                      │
     │                          │   data: {              │
     │                          │     action: "lifecycle"│
     │                          │     content: {         │
     │                          │       event: "focused" │
     │                          │     }                  │
     │                          │   }                    │
     │                          │ }                      │
     │                          │                        │
     │                          │ evaluateJavascript(    │
     │                          │   "window.bridge._handleNativeMessage(...)"
     │                          │ ) ──────────────────────> 
     │                          │                        │
     │                          │                        │ bridge._handleNativeMessage()
     │                          │                        │ triggers registered handler
     │                          │                        │
     │                          │                        │ window.bridge.on((msg) => {
     │                          │                        │   // Handle lifecycle event
     │                          │                        │   refreshData();
     │                          │                        │ })
     │                          │                        │
     │                          │                        │ [Optional] return response
     │                          │ <────────────────────── │
     │                          │                        │
     │ [Optional] callback      │                        │
     │ invoked                  │                        │
     │ <─────────────────────── │                        │
     │                          │                        │
```

**Key Points:**
- Fire-and-forget pattern: native doesn't wait for web response
- Web registers ONE handler for ALL native→web events
- Handler routes events based on `action` field
- No blocking on native side - events pushed asynchronously

---

### 3. Fire-and-Forget (Analytics)

```
┌──────┐                    ┌──────────┐                    ┌─────────┐
│ Web  │                    │  Bridge  │                    │ Handler │
│(JS)  │                    │  Layer   │                    │Registry │
└──────┘                    └──────────┘                    └─────────┘
   │                              │                              │
   │  bridge.call({              │                              │
   │    action: 'trackEvent',    │                              │
   │    content: {...}           │                              │
   │  })  [NO await]             │                              │
   │  ─────────────────────────> │                              │
   │                              │                              │
   │  Promise returned            │                              │
   │  (but not awaited)           │                              │
   │ <───────────────────────────│                              │
   │                              │                              │
   │  Continue execution          │ Parse message                │
   │  immediately                 │ ──────────────────────────> │
   │                              │                              │
   │                              │                              │ Track event
   │                              │                              │ (async)
   │                              │                              │
   │                              │ <────────────────────────── │
   │                              │ returns null                 │
   │                              │ (no response needed)         │
   │                              │                              │
   │  [Promise resolves           │                              │
   │   but nobody waits]          │                              │
   │                              │                              │
```

**Key Points:**
- No `await` used - web continues immediately
- Command returns `null` - no response sent to web
- Zero user-perceived latency
- Suitable for analytics, haptics, logging

---

## Platform Implementations

### Android Implementation

#### JavaScriptBridge.kt

```kotlin
class JavaScriptBridge(
    private val webView: WebView,
    private val messageHandler: BridgeMessageHandler
) {
    companion object {
        const val BRIDGE_NAME = "Bridge"       // window.Bridge in JavaScript
        const val SCHEMA_VERSION = 1           // Current schema version
    }

    @JavascriptInterface
    fun postMessage(message: String) {
        scope.launch {
            // 1. Parse JSON message
            val messageObj = JSONObject(message)
            val id = messageObj.optString("id")
            val data = messageObj.optJSONObject("data")
            
            // 2. Version check - silently ignore future versions
            val requestedVersion = data.optInt("version", SCHEMA_VERSION)
            if (requestedVersion > SCHEMA_VERSION) {
                return@launch  // Graceful degradation
            }
            
            // 3. Extract action & content
            val action = data.optString("action")
            val content = data.opt("content")
            
            // 4. Dispatch to command handler
            val result = messageHandler.handle(action, content)
            
            // 5. Send response if request had ID
            if (!id.isNullOrEmpty()) {
                sendResponseToWeb(id, result)
            }
        }
    }
    
    fun sendToWeb(action: String, content: Any? = null) {
        val message = buildMessage(null, action, content)
        val script = "window.bridge && window.bridge._handleNativeMessage($message)"
        webView.evaluateJavascript(script, null)
    }
}
```

**Key Design Decisions:**
- `@JavascriptInterface` required by Android security model
- Coroutines prevent ANR (Application Not Responding) during slow operations
- Silent version mismatch handling enables progressive enhancement
- Optional response pattern supports both fire-and-forget and async/await

#### Command Pattern (Strategy Pattern)

```kotlin
interface BridgeCommand {
    val action: String                        // e.g., "deviceInfo"
    suspend fun handle(content: Any?): Any?   // Returns data or null
}

class DeviceInfoCommand : BridgeCommand {
    override val action = "deviceInfo"
    
    override suspend fun handle(content: Any?): JSONObject {
        return JSONObject().apply {
            put("platform", "Android")
            put("osVersion", Build.VERSION.RELEASE)
            put("manufacturer", Build.MANUFACTURER)
            put("model", Build.MODEL)
        }
    }
}

class DefaultBridgeMessageHandler : BridgeMessageHandler {
    private val commands = listOf(
        DeviceInfoCommand(),
        ShowToastCommand(),
        NavigationCommand(),
        RefreshCommand(),
        // ... ~20 commands
    )
    
    override suspend fun handle(action: String, content: Any?): Any? {
        val command = commands.find { it.action == action }
        return command?.handle(content) 
            ?: createErrorResponse("UNKNOWN_ACTION")
    }
}
```

**Benefits:**
- ✅ Adding new commands is trivial (implement interface, add to list)
- ✅ Each command is isolated and testable
- ✅ No coupling between commands
- ✅ Commands can be reused across different bridge implementations

---

### iOS Implementation

While the iOS implementation is in a separate repository, it follows the same architecture:

```swift
// Conceptual iOS structure (WKWebView)

class JavaScriptBridge {
    private let webView: WKWebView
    private let messageHandler: BridgeMessageHandler
    
    func postMessage(message: [String: Any]) {
        // 1. Parse message dictionary
        // 2. Version check
        // 3. Extract action & content
        // 4. Dispatch to command handler
        // 5. Send response via evaluateJavaScript
    }
    
    func sendToWeb(action: String, content: Any?) {
        let script = """
            window.bridge && window.bridge._handleNativeMessage({
                data: { action: '\(action)', content: \(content) }
            })
        """
        webView.evaluateJavaScript(script)
    }
}

// WKScriptMessageHandler protocol for receiving messages from JS
```

**Key Differences from Android:**
- Uses `WKScriptMessageHandler` instead of `@JavascriptInterface`
- Swift async/await instead of Kotlin coroutines
- Otherwise identical architecture and message protocol

---

## Unified JavaScript Layer

### The Magic: Platform-Agnostic API

The **injected JavaScript bridge** is what makes the API unified. It's the same code on both platforms:

```javascript
(function() {
    'use strict';
    
    const SCHEMA_VERSION = 1;  // Injected from native
    const pendingPromises = new Map();
    
    const bridge = {
        schemaVersion: SCHEMA_VERSION,
        
        // Main async/await interface
        call(message, options = {}) {
            return new Promise((resolve, reject) => {
                const id = generateId();
                const timeout = options.timeout ?? 30000;
                
                // Set up timeout
                const timeoutId = setTimeout(() => {
                    pendingPromises.delete(id);
                    reject(new Error(`Request timeout after ${timeout}ms`));
                }, timeout);
                
                // Store promise handlers
                pendingPromises.set(id, {
                    resolve: (data) => {
                        clearTimeout(timeoutId);
                        pendingPromises.delete(id);
                        resolve(data);
                    },
                    reject: (error) => {
                        clearTimeout(timeoutId);
                        pendingPromises.delete(id);
                        reject(error);
                    }
                });
                
                // Send to native (platform-specific interface)
                const fullMessage = {
                    version: SCHEMA_VERSION,
                    id,
                    data: message.data
                };
                
                // Android: window.Bridge.postMessage(JSON.stringify(fullMessage))
                // iOS: window.webkit.messageHandlers.Bridge.postMessage(fullMessage)
                window.Bridge.postMessage(JSON.stringify(fullMessage));
            });
        },
        
        // Event subscription
        on(handler) {
            messageHandler = handler;
        },
        
        // Internal: Called by native to resolve promises
        _handleNativeResponse(response) {
            const promise = pendingPromises.get(response.id);
            if (!promise) return;
            
            if (response.error) {
                promise.reject(new Error(response.error.message));
            } else {
                promise.resolve(response.data);
            }
        },
        
        // Internal: Called by native to send events
        _handleNativeMessage(message) {
            if (messageHandler) {
                messageHandler(message);
            }
        }
    };
    
    // Freeze and expose
    Object.defineProperty(window, 'bridge', {
        value: Object.freeze(bridge),
        writable: false,
        configurable: false
    });
})();
```

**Why This Works:**

1. **Same API surface**: Web developers call `window.bridge.call()` on both platforms
2. **Platform detection inside**: The JS layer adapts to platform-specific native interfaces
3. **Promise abstraction**: Hides complexity of request/response correlation
4. **Timeout protection**: Prevents hanging on unresponsive native code
5. **Type safety**: Consistent JSON contracts across platforms

---

## Fire-and-Forget vs Async/Await

### Fire-and-Forget Pattern

**Use Cases:**
- Analytics events
- Haptic feedback
- Logging
- Non-critical operations

**Example:**
```javascript
// No await - fire and forget
bridge.call({
    data: { action: 'trackEvent', content: { event: 'page_view' } }
});
// Execution continues immediately
```

**Implementation:**
```kotlin
class TrackEventCommand : BridgeCommand {
    override suspend fun handle(content: Any?): JSONObject? {
        // Track event asynchronously
        C24Tracker.trackEvent(...)
        
        // Return null = no response sent to web
        return null
    }
}
```

**Benefits:**
- ✅ Zero user-perceived latency
- ✅ Doesn't block UI thread
- ✅ Suitable for observability/telemetry

---

### Async/Await Pattern

**Use Cases:**
- Device info queries
- Navigation with confirmation
- Secure storage operations
- Any operation needing result

**Example:**
```javascript
// Await response
try {
    const info = await bridge.call(
        { data: { action: 'deviceInfo' } },
        { timeout: 5000 }
    );
    console.log('Running on:', info.platform);
} catch (error) {
    console.error('Failed:', error.message);
}
```

**Implementation:**
```kotlin
class DeviceInfoCommand : BridgeCommand {
    override suspend fun handle(content: Any?): JSONObject {
        return JSONObject().apply {
            put("platform", "Android")
            put("model", Build.MODEL)
        }
    }
}
```

**Benefits:**
- ✅ Web code can react to results
- ✅ Error handling via try/catch
- ✅ Synchronous-style programming

---

## Schema Versioning

### Why Versioning Matters

**Problem:** Web and native apps deploy independently
- Web update may use new features not in old native app
- Native update may deprecate features web still uses
- Need graceful degradation, not crashes

**Solution:** Simple integer versioning with forward compatibility

### Version Check Flow

```
Web sends:           Native receives:         Native action:
─────────────────    ──────────────────       ─────────────────────────
version: 1           SCHEMA_VERSION: 1        ✅ Process (same version)

version: 1           SCHEMA_VERSION: 2        ✅ Process (backward compat)

version: 2           SCHEMA_VERSION: 1        ⚠️  Silently ignore (future version)
                                              Web times out → fallback
```

### Implementation

```kotlin
// Android
@JavascriptInterface
fun postMessage(message: String) {
    val requestedVersion = data.optInt("version", SCHEMA_VERSION)
    if (requestedVersion > SCHEMA_VERSION) {
        ProfiLogger.w("Ignoring future version $requestedVersion")
        return  // Silent ignore - web will timeout
    }
    // Process message...
}
```

```javascript
// Web - version gating
const version = window.bridge.schemaVersion;

if (version >= 2) {
    // Use new feature from v2
    await bridge.call({ data: { action: 'newFeatureV2' } });
} else {
    // Fallback for v1
    console.log('Feature not available, using alternative');
}
```

### Versioning Strategy

**When to increment:**
- ✅ Breaking change to message format
- ✅ Removing a command
- ✅ Changing command behavior in incompatible way

**When NOT to increment:**
- ✅ Adding new commands (old web ignores them)
- ✅ Adding optional fields to existing commands
- ✅ Bug fixes that don't change API

**Example - Adding Optional Field (No version bump):**
```javascript
// v1 command
{ action: 'showToast', content: { message: 'Hi' } }

// v1 with new optional field (still v1!)
{ action: 'showToast', content: { message: 'Hi', duration: 'long' } }
```

---

## Example Command: Adding New Feature

Let's walk through adding a `vibrate` command to demonstrate extensibility:

### 1. Define Command Interface

```kotlin
// Android: HapticCommand.kt
class HapticCommand : BridgeCommand {
    
    override val action = "haptic"
    
    override suspend fun handle(content: Any?): JSONObject? = withContext(Dispatchers.Main) {
        try {
            // Parse vibrate parameter
            val shouldVibrate = BridgeParsingUtils.parseBoolean(content, "vibrate")
            
            if (shouldVibrate) {
                // Get vibrator service
                val context = ActivityProvider.currentActivity ?: application
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                
                // Trigger haptic feedback
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(
                        VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(50)
                }
            }
            
            // Fire-and-forget: return null (no response needed)
            null
            
        } catch (e: Exception) {
            ProfiLogger.e("[HapticCommand] Error", e)
            // Even errors are fire-and-forget for haptics
            null
        }
    }
}
```

### 2. Register Command

```kotlin
// Android: DefaultBridgeMessageHandler.kt
class DefaultBridgeMessageHandler : BridgeMessageHandler {
    private val commands = listOf(
        DeviceInfoCommand(),
        ShowToastCommand(),
        // ... existing commands ...
        HapticCommand()  // ← Add here
    )
}
```

### 3. Document for Web Developers

```markdown
### `haptic`

Triggers haptic/vibration feedback.

**Usage:**
```javascript
await bridge.call({
  data: {
    action: 'haptic',
    content: { vibrate: true }
  }
});
```

**Parameters:**
- `content.vibrate` (boolean, required): Whether to vibrate
```

### That's It!

**What we didn't need to touch:**
- ❌ Bridge infrastructure (`JavaScriptBridge.kt`)
- ❌ Message parsing/routing logic
- ❌ JavaScript API (`window.bridge`)
- ❌ iOS implementation (implements same interface)

**Benefits of this approach:**
- ✅ 3 files touched (command, handler, docs)
- ✅ ~50 lines of code
- ✅ Fully isolated from other commands
- ✅ Testable in isolation
- ✅ Works on both platforms with same API

---

## Lifecycle Events Deep Dive

### Implementation

```kotlin
// Android: PluginWebFragment.kt
override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    
    val event = if (hasFocus) "focused" else "defocused"
    
    sendToWeb(
        action = "lifecycle",
        content = mapOf("event" to event)
    )
}
```

### Web Usage

```javascript
// 1. Subscribe to lifecycle events
window.bridge.on((message) => {
    const { action, content } = message.data || {};
    
    if (action === 'lifecycle') {
        if (content?.event === 'focused') {
            console.log('Screen gained focus');
            refreshData();      // Refresh data when user returns
            resumeAnimations(); // Resume paused work
        } else if (content?.event === 'defocused') {
            console.log('Screen lost focus');
            pauseAnimations();  // Save battery
            saveState();        // Persist state
        }
    }
});
```

### Common Use Cases

**Focused Event:**
- Refresh data from server
- Resume animations/videos
- Re-establish WebSocket connections
- Restart timers

**Defocused Event:**
- Pause media playback
- Save form state
- Close WebSocket connections
- Stop polling

---

## Recommendations for Web Developers

### 1. Unified Abstraction Layer 🎯

**What it is:**  
The JavaScript layer abstracts platform differences. Web developers never need to know if they're on Android or iOS.

**Why it matters:**
```javascript
// ✅ Write once, works everywhere
await window.bridge.call({ data: { action: 'deviceInfo' } });

// ❌ Instead of platform-specific code:
if (isAndroid) {
    window.Android.getDeviceInfo();
} else if (isIOS) {
    window.webkit.messageHandlers.getDeviceInfo.postMessage({});
}
```

**Best Practice:**
- Use `window.bridge.schemaVersion` for capability detection
- Never check platform directly in web code
- Let the bridge handle platform differences

---

### 2. Promise-Based Modern API 🚀

**What it is:**  
Async/await syntax instead of callbacks.

**Why it matters:**
```javascript
// ✅ Modern, readable
try {
    const info = await bridge.call({ data: { action: 'deviceInfo' } });
    const status = await bridge.call({ data: { action: 'networkState' } });
    displayDashboard(info, status);
} catch (error) {
    showError(error.message);
}

// ❌ Callback hell alternative:
getDeviceInfo(function(info) {
    getNetworkState(function(status) {
        displayDashboard(info, status);
    }, function(error) {
        showError(error);
    });
}, function(error) {
    showError(error);
});
```

---

### 3. Fire-and-Forget for Performance 🏎️

**What it is:**  
Don't await operations that don't need responses.

**Why it matters:**
```javascript
// ✅ Fire and forget - zero latency
function trackButtonClick(button) {
    bridge.call({
        data: { action: 'trackEvent', content: { event: 'click', button } }
    });
    // Continues immediately - user sees instant response
    navigateToPage();
}

// ❌ Unnecessary await adds latency
async function trackButtonClick(button) {
    await bridge.call({
        data: { action: 'trackEvent', content: { event: 'click', button } }
    });
    // User waits ~50ms for tracking before navigation
    navigateToPage();
}
```

**Use fire-and-forget for:**
- Analytics events
- Logging
- Haptic feedback
- Non-critical operations

---

### 4. Command-Based Extensibility 📦

**What it is:**  
The API doesn't change when adding features. Only the `action` changes.

**Why it matters:**
```javascript
// Same call pattern for ALL features:
await bridge.call({ data: { action: 'ACTION_NAME', content: {...} } });

// Examples:
await bridge.call({ data: { action: 'deviceInfo' } });
await bridge.call({ data: { action: 'showToast', content: { message: 'Hi' } } });
await bridge.call({ data: { action: 'navigate', content: { url: '...' } } });
await bridge.call({ data: { action: 'haptic', content: { vibrate: true } } });
```

**Benefits:**
- ✅ Learn one pattern, use everywhere
- ✅ Adding features doesn't break existing code
- ✅ Easy to extend (just add new action)
- ✅ Consistent error handling

---

### 5. Version-Safe Progressive Enhancement 🔢

**What it is:**  
Check version before using new features, provide fallbacks.

**Why it matters:**
```javascript
// ✅ Graceful degradation
const version = window.bridge.schemaVersion;

if (version >= 2) {
    // Use new feature from schema v2
    await bridge.call({ data: { action: 'advancedFeature' } });
} else {
    // Fallback for older versions
    console.log('Feature unavailable, using alternative');
    useBasicFeature();
}

// ❌ Crash on older apps:
await bridge.call({ data: { action: 'advancedFeature' } });
// Times out on old native versions → bad UX
```

---

### 6. Timeout Handling for Reliability ⏱️

**What it is:**  
Always set reasonable timeouts and handle failures.

**Why it matters:**
```javascript
// ✅ Timeout prevents hanging
try {
    const info = await bridge.call(
        { data: { action: 'deviceInfo' } },
        { timeout: 5000 }  // 5 second timeout
    );
    displayInfo(info);
} catch (error) {
    if (error.message.includes('timeout')) {
        console.warn('Native not responding, using defaults');
        displayInfo(DEFAULT_INFO);
    } else {
        showError(error.message);
    }
}

// ❌ No timeout - user waits 30 seconds on failure
const info = await bridge.call({ data: { action: 'deviceInfo' } });
```

**Recommended timeouts:**
- Quick operations (device info, network status): 3-5 seconds
- UI operations (toasts, alerts): 5-10 seconds
- Heavy operations (file operations): 15-30 seconds
- Analytics (fire-and-forget): No await needed

---

### 7. Single Event Handler Pattern 📡

**What it is:**  
Register ONE handler for all native→web events.

**Why it matters:**
```javascript
// ✅ Single handler, route by action
window.bridge.on((message) => {
    const { action, content } = message.data || {};
    
    switch (action) {
        case 'lifecycle':
            handleLifecycle(content);
            break;
        case 'onPushNotification':
            handlePush(content);
            break;
        case 'networkChanged':
            handleNetwork(content);
            break;
        default:
            console.log('Unknown action:', action);
    }
});

// ❌ Multiple subscriptions can cause issues
window.bridge.on(handleLifecycle);  // Don't do this
window.bridge.on(handlePush);       // Multiple handlers
window.bridge.on(handleNetwork);    // Overwrites previous
```

---

### 8. Type Safety with TypeScript 🔒

**Recommendation:**  
Define TypeScript types for bridge messages.

```typescript
// Define message types
interface BridgeMessage {
    data: {
        action: string;
        content?: unknown;
    };
}

interface BridgeOptions {
    timeout?: number;
}

interface DeviceInfo {
    platform: 'iOS' | 'Android';
    osVersion: string;
    manufacturer: string;
    model: string;
    appVersion: string;
}

// Type-safe bridge interface
interface Bridge {
    schemaVersion: number;
    ready(): Promise<void>;
    setDebug(enabled: boolean): void;
    call<T = unknown>(message: BridgeMessage, options?: BridgeOptions): Promise<T>;
    on(handler: (message: BridgeMessage) => void | Promise<void>): void;
}

// Usage with type safety
declare global {
    interface Window {
        bridge: Bridge;
    }
}

// Type-safe calls
const info = await window.bridge.call<DeviceInfo>({
    data: { action: 'deviceInfo' }
});

console.log(info.platform); // TypeScript knows this is 'iOS' | 'Android'
```

---

### 9. Error Handling Best Practices ⚠️

```javascript
// ✅ Comprehensive error handling
async function safeDeviceInfo() {
    try {
        const info = await window.bridge.call(
            { data: { action: 'deviceInfo' } },
            { timeout: 5000 }
        );
        return info;
    } catch (error) {
        // Log error for debugging
        console.error('Bridge error:', error);
        
        // Track error for monitoring
        analytics.trackError('bridge_device_info_failed', { error: error.message });
        
        // Provide fallback
        return {
            platform: 'unknown',
            model: 'unknown',
            osVersion: 'unknown'
        };
    }
}
```

---

### 10. Performance Optimization 🚄

**Batch Operations:**
```javascript
// ✅ Parallel requests
const [info, network, storage] = await Promise.all([
    bridge.call({ data: { action: 'deviceInfo' } }),
    bridge.call({ data: { action: 'networkState' } }),
    bridge.call({ data: { action: 'loadSecureData', content: { key: 'token' } } })
]);

// ❌ Sequential - 3x slower
const info = await bridge.call({ data: { action: 'deviceInfo' } });
const network = await bridge.call({ data: { action: 'networkState' } });
const storage = await bridge.call({ data: { action: 'loadSecureData' } });
```

**Cache Results:**
```javascript
// Cache device info (doesn't change during session)
let cachedDeviceInfo = null;

async function getDeviceInfo() {
    if (!cachedDeviceInfo) {
        cachedDeviceInfo = await bridge.call({ data: { action: 'deviceInfo' } });
    }
    return cachedDeviceInfo;
}
```

---

## Testing

### Unit Testing Commands (Android)

```kotlin
class DeviceInfoCommandTest {
    @Test
    fun `deviceInfo returns expected fields`() = runBlocking {
        val command = DeviceInfoCommand()
        val result = command.handle(null) as JSONObject
        
        assertEquals("Android", result.getString("platform"))
        assertNotNull(result.getString("osVersion"))
        assertNotNull(result.getString("model"))
    }
}
```

### Integration Testing Bridge

```kotlin
class JavaScriptBridgeTest {
    @Test
    fun `postMessage with valid action returns response`() = runBlocking {
        val handler = mock(BridgeMessageHandler::class.java)
        val bridge = JavaScriptBridge(webView, handler)
        
        val message = """
            {
                "id": "test_123",
                "data": { "action": "deviceInfo" }
            }
        """.trimIndent()
        
        bridge.postMessage(message)
        
        verify(handler).handle("deviceInfo", null)
    }
}
```

### E2E Testing from Web

```javascript
describe('Bridge', () => {
    beforeAll(async () => {
        await window.bridge.ready();
    });

    it('should get device info', async () => {
        const info = await window.bridge.call({
            data: { action: 'deviceInfo' }
        });
        
        expect(info.platform).toMatch(/iOS|Android/);
        expect(info.model).toBeDefined();
    });

    it('should handle unknown action', async () => {
        await expect(
            window.bridge.call({ data: { action: 'unknownAction' } })
        ).rejects.toThrow('UNKNOWN_ACTION');
    });

    it('should timeout on long operations', async () => {
        await expect(
            window.bridge.call(
                { data: { action: 'slowOperation' } },
                { timeout: 1000 }
            )
        ).rejects.toThrow('timeout');
    });
});
```

---

## Security Considerations

### 1. JavaScript Injection Protection

**Android:**
```kotlin
// ✅ Only methods with @JavascriptInterface are exposed
@JavascriptInterface
fun postMessage(message: String) { ... }

// ❌ Without annotation, not accessible from JavaScript
fun internalMethod() { ... }
```

**Web:**
```javascript
// Bridge is frozen - cannot be modified by web code
Object.defineProperty(window, 'bridge', {
    value: Object.freeze(bridge),
    writable: false,
    configurable: false
});
```

### 2. Message Validation

```kotlin
@JavascriptInterface
fun postMessage(message: String) {
    try {
        val messageObj = JSONObject(message)
        
        // Validate required fields
        require(messageObj.has("data")) { "Missing data field" }
        
        val data = messageObj.getJSONObject("data")
        require(data.has("action")) { "Missing action field" }
        
        // Validate action is not malicious
        val action = data.getString("action")
        require(action.matches(Regex("^[a-zA-Z0-9_]+$"))) {
            "Invalid action format"
        }
        
    } catch (e: Exception) {
        sendErrorToWeb(null, "INVALID_MESSAGE", e.message)
    }
}
```

### 3. Content Security Policy (CSP)

Ensure WebView has appropriate CSP headers to prevent XSS attacks.

---

## Performance Characteristics

### Latency Measurements

| Operation | Typical Latency | Notes |
|-----------|----------------|-------|
| Fire-and-forget | < 1ms | No network round-trip |
| Device info query | 5-15ms | Simple data retrieval |
| UI operations (toast) | 10-30ms | Requires main thread |
| Secure storage | 20-50ms | Encryption overhead |
| Network operations | 100-1000ms+ | Depends on network |

### Optimization Tips

1. **Batch requests**: Use `Promise.all()` for parallel operations
2. **Cache results**: Device info doesn't change during session
3. **Fire-and-forget**: Don't await analytics/logging
4. **Lazy initialization**: Don't call bridge during page load unless needed
5. **Debounce**: For frequent calls (scroll events), debounce before calling native

---

## Troubleshooting

### Common Issues

**1. Bridge not available**
```javascript
// ✅ Always check bridge is ready
await window.bridge.ready();

// ❌ Calling before bridge initialized
window.bridge.call(...); // Error: bridge is undefined
```

**2. Timeout errors**
```javascript
// Increase timeout for slow operations
await bridge.call(
    { data: { action: 'slowOperation' } },
    { timeout: 30000 }  // 30 seconds
);
```

**3. Version mismatch**
```javascript
// Check version and provide fallback
if (window.bridge.schemaVersion >= 2) {
    // Use new feature
} else {
    // Use old approach or show error
}
```

**4. Events not received**
```javascript
// Register handler BEFORE sending commands
window.bridge.on(handler);

// Then make calls
await bridge.call({ data: { action: 'lifecycleEvents', content: { enable: true } } });
```

---

## Migration Guide

### From Legacy Callback-Based API

**Before:**
```javascript
// Old callback style
window.Android.getDeviceInfo(function(info) {
    console.log(info);
}, function(error) {
    console.error(error);
});
```

**After:**
```javascript
// New promise-based bridge
try {
    const info = await window.bridge.call({
        data: { action: 'deviceInfo' }
    });
    console.log(info);
} catch (error) {
    console.error(error);
}
```

---

## Complete Example: Dashboard Screen

```javascript
/**
 * Dashboard screen demonstrating bridge best practices
 */

class Dashboard {
    constructor() {
        this.deviceInfo = null;
        this.initialized = false;
    }

    async init() {
        try {
            // 1. Wait for bridge
            await window.bridge.ready();
            console.log('Bridge ready, version:', window.bridge.schemaVersion);

            // 2. Enable debug in development
            if (import.meta.env.DEV) {
                window.bridge.setDebug(true);
            }

            // 3. Register event listener ONCE
            window.bridge.on(this.handleNativeEvent.bind(this));

            // 4. Fetch initial data (parallel)
            const [deviceInfo, networkStatus] = await Promise.all([
                this.getDeviceInfo(),
                this.getNetworkStatus()
            ]);

            // 5. Enable lifecycle events
            await window.bridge.call({
                data: { action: 'lifecycleEvents', content: { enable: true } }
            });

            // 6. Configure UI based on platform
            this.setupUI(deviceInfo);

            // 7. Track page view (fire-and-forget)
            window.bridge.call({
                data: {
                    action: 'trackScreen',
                    content: { screenName: 'Dashboard' }
                }
            });

            this.initialized = true;
            
        } catch (error) {
            console.error('Dashboard init failed:', error);
            this.showError('Failed to initialize. Please refresh.');
        }
    }

    async getDeviceInfo() {
        // Cache device info (doesn't change)
        if (this.deviceInfo) return this.deviceInfo;

        try {
            this.deviceInfo = await window.bridge.call(
                { data: { action: 'deviceInfo' } },
                { timeout: 5000 }
            );
            return this.deviceInfo;
        } catch (error) {
            console.error('Failed to get device info:', error);
            return { platform: 'unknown', model: 'unknown' };
        }
    }

    async getNetworkStatus() {
        try {
            return await window.bridge.call(
                { data: { action: 'networkState' } },
                { timeout: 3000 }
            );
        } catch (error) {
            console.error('Failed to get network status:', error);
            return { connected: false };
        }
    }

    handleNativeEvent(message) {
        const { action, content } = message.data || {};

        switch (action) {
            case 'lifecycle':
                if (content?.event === 'focused') {
                    console.log('App resumed - refreshing data');
                    this.refreshData();
                } else if (content?.event === 'defocused') {
                    console.log('App paused - saving state');
                    this.saveState();
                }
                break;

            case 'onPushNotification':
                console.log('Push notification received:', content);
                this.handlePushNotification(content);
                break;

            default:
                console.log('Unknown event:', action);
        }
    }

    async refreshData() {
        // Parallel refresh
        const [networkStatus, userData] = await Promise.all([
            this.getNetworkStatus(),
            this.fetchUserData()
        ]);

        this.updateUI(networkStatus, userData);
    }

    async showSuccessMessage(message) {
        try {
            await window.bridge.call({
                data: {
                    action: 'showToast',
                    content: { message, duration: 'short' }
                }
            }, { timeout: 3000 });
        } catch (error) {
            // Fallback to web toast
            console.error('Native toast failed:', error);
            this.showWebToast(message);
        }
    }

    setupUI(deviceInfo) {
        // Adapt UI based on platform
        if (deviceInfo.platform === 'iOS') {
            this.applyIOSStyles();
        } else if (deviceInfo.platform === 'Android') {
            this.applyAndroidStyles();
        }

        // Use version-specific features
        if (window.bridge.schemaVersion >= 2) {
            this.enableAdvancedFeatures();
        }
    }

    cleanup() {
        // Disable lifecycle events when leaving screen
        window.bridge.call({
            data: { action: 'lifecycleEvents', content: { enable: false } }
        });
    }
}

// Initialize dashboard
const dashboard = new Dashboard();
dashboard.init();
```

---

## Summary

### Architecture Strengths

✅ **Unified Interface**: Write once, works on iOS and Android  
✅ **Modern API**: Promise-based async/await instead of callbacks  
✅ **Extensible**: Adding features requires minimal code changes  
✅ **Version-Safe**: Graceful degradation on version mismatches  
✅ **Performant**: Fire-and-forget for non-critical operations  
✅ **Testable**: Command pattern enables isolated unit tests  
✅ **Secure**: Platform security best practices enforced  
✅ **Maintainable**: Clear separation of concerns

### Key Takeaways for Web Developers

1. **Use `window.bridge.ready()`** before any bridge calls
2. **Don't await** analytics/logging (fire-and-forget)
3. **Check `schemaVersion`** before using new features
4. **Set reasonable timeouts** and handle failures
5. **Register ONE event handler** for native→web messages
6. **Cache device info** - it doesn't change during session
7. **Use Promise.all()** for parallel operations
8. **Provide fallbacks** for better UX

---

## References

- **Android Implementation**: `android-sample/app/src/main/java/com/check24/bridgesample/bridge/JavaScriptBridge.kt`
- **Command Registry**: `android-sample/app/src/main/assets/index.html`
- **JavaScript API Documentation**: `js.md`
- **Live Demo**: `pluginapi/src/debug/assets/c24/index.html`
- **Check-mate Specification**: https://github.com/kibotu/check-mate

**Questions or issues?** Contact the mobile team or check the bridge demo for working examples of every feature.

