# JavaScript Bridge Specification

## Overview

A minimal, JSON-based bidirectional communication bridge between native iOS/Android and WebView.

**Core Principles:** 
- **Minimal API**: Only 2 methods
- **Pure JSON**: No method/param parsing. Just JSON in, JSON out
- **Version-proof**: Tiny API surface eliminates versioning issues
- **Self-documenting**: Behavior emerges from usage (await vs no-await, return vs no-return)
- **Async/await everywhere**: No callbacks, no promise chains

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Core API](#core-api)
3. [Message Format](#message-format)
4. [TypeScript Interface](#typescript-interface)
5. [API Design Philosophy](#api-design-philosophy)
6. [Usage Examples](#usage-examples)
7. [Platform-Specific Implementation](#platform-specific-implementation)
   - [Web-Side Bridge Implementation](#web-side-bridge-implementation)
   - [iOS (WKWebView)](#ios-wkwebview)
   - [Android (WebView)](#android-webview)
8. [Common Actions to Implement](#common-actions-to-implement)
9. [Testing](#testing)
10. [Security & Performance](#security--performance)
11. [Implementation Roadmap](#implementation-roadmap)

---

## Quick Reference

**The Entire API:**

```javascript
// Web → Native (ONE method, pass JSON)
window.bridge.call(message, options?)

// Native → Web (ONE method, receive JSON)
window.bridge.on(handler)
window.bridge.off()

// Lifecycle
await window.bridge.ready()  // async
window.bridge.isReady        // boolean

// Utility
window.bridge.setDebug(enabled)
```

**Usage Patterns:**

```javascript
// Fire-and-forget: Don't await
window.bridge.call({
  data: {
    action: 'trackEvent',
    content: { event: 'click', timestamp: Date.now() }
  }
});

// Request-response: Await it
const result = await window.bridge.call({
  data: {
    action: 'getUser',
    content: { id: 123 }
  }
});

// Handler for incoming messages from native
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  
  switch (action) {
    case 'locationUpdate':
      await updateMap(content);
      return; // No response needed
      
    case 'processPayment':
      const result = await processPayment(content);
      return { success: true, result }; // Response sent back
      
    default:
      return { error: 'Unknown action' };
  }
});
```

---

## Core API

### Web → Native

**Single Method: `call(message, options?)`**

Pass JSON. Await if you want a response.

```javascript
// Fire-and-forget: Don't await
window.bridge.call({
  data: {
    action: 'commandName',
    content: { /* payload */ }
  }
});

// Request-response: Await for result
const result = await window.bridge.call({
  data: {
    action: 'commandName',
    content: { /* payload */ }
  }
}, { timeout: 5000 });
```

### Native → Web

**Single Handler: `on(handler)`**

Register a global handler for all incoming messages.

```javascript
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  
  switch (action) {
    case 'someAction':
      return { result: 'value' };
    default:
      return { error: 'Unknown action' };
  }
});

// Remove handler
window.bridge.off();
```

---

## Message Format

All messages are JSON objects with this structure:

```json
{
  "version": "1.0",            // Schema version (always "1.0" for now)
  "data": {
    "action": "string",        // Required: The command/action to execute
    "content": {}              // Optional: The payload/parameters
  }
}
```

**That's it.** Everything is in `data.action` and `data.content`. The `version` field tracks the message schema version for future compatibility.

### Internal Format (Bridge Implementation Detail)

The bridge internally adds an `id` for request-response tracking:

```json
{
  "version": "1.0",
  "data": {
    "action": "string",
    "content": {}
  },
  "id": "string"               // Added by bridge for awaited calls
}
```

### Response Format

Responses are just JSON. Return whatever you want:

```json
{
  "result": "success",
  "user": { "id": 123, "name": "John" }
}
```

### Error Format

```json
{
  "error": {
    "code": "UNKNOWN_ACTION",
    "message": "Action 'foo' not supported"
  }
}
```

**Standard Error Codes:**
- `TIMEOUT` - Request timed out
- `NOT_IMPLEMENTED` - Action not implemented
- `INVALID_PARAMS` - Invalid parameters
- `PERMISSION_DENIED` - Permission denied
- `UNKNOWN_ACTION` - Action not recognized

---

## TypeScript Interface

```typescript
interface Bridge {
  // State
  readonly isReady: boolean;
  readonly version: string;
  
  // Lifecycle
  ready(): Promise<void>;
  
  // Web → Native
  call<T = any>(
    message: BridgeMessage,
    options?: CallOptions
  ): Promise<T>;
  
  // Native → Web
  on(handler: MessageHandler): void;
  off(): void;
  
  // Utility
  setDebug(enabled: boolean): void;
}

interface BridgeMessage {
  version: string;   // Schema version (e.g., "1.0")
  data: {
    action: string;
    content?: any;
  };
}

interface CallOptions {
  timeout?: number;      // milliseconds (default: 30000)
  signal?: AbortSignal;  // AbortController support
}

interface BridgeError extends Error {
  code: string;
  details?: any;
}

type MessageHandler = (message: BridgeMessage) => any | Promise<any> | void;

declare global {
  interface Window {
    bridge: Bridge;
  }
}
```

---

## API Design Philosophy

### Why This Design?

**Traditional Approach: Multiple methods, multiple parameters**
```javascript
window.bridge.send("track", { event: "click" });
window.bridge.call("getUser", { id: 123 });
window.bridge.handle("payment", handler);
window.bridge.on("event", listener);
```

**This Design: Two methods, pure JSON**
```javascript
// ONE method for web→native
window.bridge.call({ data: { action: "track", content: { event: "click" } } });
await window.bridge.call({ data: { action: "getUser", content: { id: 123 } } });

// ONE handler for native→web
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  switch (action) {
    case 'payment': return { result };
    case 'event': return; // fire-and-forget
  }
});
```

### Key Advantages

1. **Smaller API surface** = fewer versioning issues
2. **Pure JSON everywhere**: No method names, no parameter parsing
3. **Self-documenting behavior**: 
   - Await it? You want a response
   - Don't await? Fire-and-forget
   - Return value? Send it back
   - No return? Just an event
4. **Easier to implement**: One code path on each side
5. **Future-proof**: Add new actions without touching bridge code
6. **Native controls the schema**: Native decides what actions are valid

### Design Principles

1. **Radically Minimal**: Only 2 core methods: `call()` and `on()`
2. **Pure JSON Everything**: Bridge doesn't parse structure - native does
3. **Self-Documenting Behavior**: Usage pattern indicates intent
4. **Version-Proof**: Tiny API surface = zero breaking changes
5. **Modern JavaScript**: Async/await everywhere, no callbacks
6. **Production Ready**: Timeout handling, error codes, debug mode

---

## Usage Examples

### Complete Web Example

```html
<!DOCTYPE html>
<html>
<head>
  <script>
    async function init() {
      // Check if running in native app
      if (!window.bridge) {
        console.log("Running in browser");
        return;
      }
      
      // Wait for bridge to be ready
      await window.bridge.ready();
      
      // Call native and await result
      const deviceInfo = await window.bridge.call({
        data: { action: 'getDeviceInfo' }
      });
      console.log("Device:", deviceInfo);
      
      // Fire-and-forget call (no await)
      window.bridge.call({
        data: {
          action: 'trackEvent',
          content: { event: 'page_load', timestamp: Date.now() }
        }
      });
      
      // Handle incoming messages from native
      window.bridge.on(async (message) => {
        const { action, content } = message.data;
        
        switch (action) {
          case 'getWebState':
            return { scrollPosition: window.scrollY, url: window.location.href };
          case 'appStateChanged':
            console.log('App state:', content.state);
            return;
          default:
            return { error: { code: 'UNKNOWN_ACTION' } };
        }
      });
    }
    
    document.addEventListener('DOMContentLoaded', init);
  </script>
</head>
<body>
  <button onclick="window.bridge.call({ data: { action: 'showToast', content: { message: 'Hello!' } } })">
    Show Toast
  </button>
</body>
</html>
```

### With Timeout and Error Handling

```javascript
try {
  const result = await window.bridge.call({
    data: {
      action: 'requestPermission',
      content: { permission: 'camera' }
    }
  }, { timeout: 5000 });
  
  console.log("Permission granted:", result.granted);
} catch (error) {
  if (error.code === 'TIMEOUT') {
    console.error('Request timed out');
  } else if (error.code === 'PERMISSION_DENIED') {
    console.error('User denied permission');
  }
}
```

### With AbortController

```javascript
const controller = new AbortController();

// Cancel after 3 seconds
setTimeout(() => controller.abort(), 3000);

try {
  const result = await window.bridge.call({
    data: { action: 'longOperation' }
  }, { signal: controller.signal });
} catch (error) {
  if (error.name === 'AbortError') {
    console.log('Operation cancelled');
  }
}
```

---

## Platform-Specific Implementation

### Web-Side Bridge Implementation

Full production-ready bridge (~200 lines):

```javascript
(function() {
  'use strict';
  
  const pendingCalls = new Map();
  let messageHandler = null;
  let messageQueue = [];
  let bridgeReady = false;
  
  window.bridge = {
    isReady: false,
    version: '1.0.0',
    
    async ready() {
      if (bridgeReady) return;
      return new Promise((resolve) => {
        window.addEventListener('bridgeReady', () => resolve(), { once: true });
      });
    },
    
    async call(message, options = {}) {
      const { timeout = 30000, signal } = options;
      const id = Math.random().toString(36).substr(2, 9);
      
      // Add version and id to message
      const messageWithId = { version: '1.0', ...message, id };
      
      return new Promise((resolve, reject) => {
        // Setup timeout
        const timeoutId = setTimeout(() => {
          pendingCalls.delete(id);
          reject(new Error('TIMEOUT'));
        }, timeout);
        
        // Setup abort signal
        if (signal) {
          signal.addEventListener('abort', () => {
            clearTimeout(timeoutId);
            pendingCalls.delete(id);
            reject(new Error('AbortError'));
          }, { once: true });
        }
        
        // Store pending call
        pendingCalls.set(id, { resolve, reject, timeoutId });
        
        // Send to native
        if (window.webkit?.messageHandlers?.bridge) {
          // iOS
          window.webkit.messageHandlers.bridge.postMessage(messageWithId);
        } else if (window.AndroidBridge) {
          // Android
          window.AndroidBridge.postMessage(JSON.stringify(messageWithId));
        } else {
          clearTimeout(timeoutId);
          pendingCalls.delete(id);
          reject(new Error('Bridge not available'));
        }
      });
    },
    
    on(handler) {
      messageHandler = handler;
    },
    
    off() {
      messageHandler = null;
    },
    
    setDebug(enabled) {
      console.log(`Bridge debug mode: ${enabled}`);
    },
    
    // Internal: Handle responses from native
    _onNativeResponse(response) {
      const { id, result, error } = response;
      const pending = pendingCalls.get(id);
      
      if (pending) {
        clearTimeout(pending.timeoutId);
        pendingCalls.delete(id);
        
        if (error) {
          pending.reject(new Error(error.message || error.code));
        } else {
          pending.resolve(result);
        }
      }
    },
    
    // Internal: Handle messages from native
    async _onNativeMessage(message) {
      if (!messageHandler) {
        console.warn('No message handler registered');
        return;
      }
      
      try {
        const result = await messageHandler(message);
        
        // If message has id, send response back
        if (message.id && result !== undefined) {
          const response = { version: '1.0', id: message.id, result };
          
          if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          } else if (window.AndroidBridge) {
            window.AndroidBridge.postMessage(JSON.stringify(response));
          }
        }
      } catch (error) {
        // Send error back if message expects response
        if (message.id) {
          const response = {
            version: '1.0',
            id: message.id,
            error: { code: 'JS_ERROR', message: error.message }
          };
          
          if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          } else if (window.AndroidBridge) {
            window.AndroidBridge.postMessage(JSON.stringify(response));
          }
        }
      }
    }
  };
  
  // Mark as ready
  bridgeReady = true;
  window.bridge.isReady = true;
  window.dispatchEvent(new Event('bridgeReady'));
  
  // Flush queued messages
  messageQueue.forEach(msg => window.bridge.call(msg));
  messageQueue = [];
})();
```

**Key Implementation Details:**

1. **Platform Detection**: Uses `window.webkit` for iOS, `window.AndroidBridge` for Android
2. **Promise Management**: Tracks pending calls with timeouts
3. **Error Handling**: Sends errors back when handler throws
4. **Ready State**: Dispatches `bridgeReady` event when initialized

---

### iOS (WKWebView)

```swift
// Inject bridge JavaScript
let script = WKUserScript(source: bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
webView.configuration.userContentController.addUserScript(script)

// Register message handler to receive messages from web
webView.configuration.userContentController.add(self, name: "bridge")

func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
  guard let json = message.body as? [String: Any],
        let data = json["data"] as? [String: Any],
        let action = data["action"] as? String else {
    return
  }
  
  let content = data["content"] as? [String: Any]
  let id = json["id"] as? String  // Present if web expects response
  
  // Handle the action on main thread
  DispatchQueue.main.async {
    switch action {
      case "getDeviceInfo":
        let result: [String: Any] = [
          "platform": "iOS",
          "version": UIDevice.current.systemVersion
        ]
        if let id = id {
          self.sendResult(id: id, result: result)
        }
        
      case "trackEvent":
        // Fire-and-forget - no response needed
        if let event = content?["event"] as? String {
          self.trackEvent(event)
        }
        
      default:
        if let id = id {
          self.sendError(id: id, code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }
  }
}

// Send result back to web
func sendResult(id: String, result: Any) {
  let response: [String: Any] = ["version": "1.0", "id": id, "result": result]
  if let jsonData = try? JSONSerialization.data(withJSONObject: response),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeResponse(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

// Send error back to web
func sendError(id: String, code: String, message: String) {
  let response: [String: Any] = [
    "version": "1.0",
    "id": id,
    "error": ["code": code, "message": message]
  ]
  if let jsonData = try? JSONSerialization.data(withJSONObject: response),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeResponse(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

// Call web (fire-and-forget)
func sendEventToWeb(action: String, content: [String: Any]) {
  let message: [String: Any] = [
    "version": "1.0",
    "data": ["action": action, "content": content]
  ]
  if let jsonData = try? JSONSerialization.data(withJSONObject: message),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeMessage(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}
```

**Critical iOS Points:**

1. **JSON Serialization**: Must use `JSONSerialization` - don't manually build JSON strings
2. **Thread Safety**: Use `DispatchQueue.main.async` for UI operations
3. **Safe Unwrapping**: Use `guard` statements instead of force unwrapping
4. **Injection Timing**: `.atDocumentStart` ensures bridge is ready before page loads

---

### Android (WebView)

```kotlin
// Setup WebView
webView.settings.javaScriptEnabled = true

// Add JavaScript interface (NOTE: Only works on HTTPS or localhost for security)
webView.addJavascriptInterface(BridgeInterface(webView), "AndroidBridge")

class BridgeInterface(private val webView: WebView) {
  private val mainHandler = Handler(Looper.getMainLooper())
  
  @JavascriptInterface
  fun postMessage(jsonString: String) {
    try {
      val msg = JSONObject(jsonString)
      val data = msg.getJSONObject("data")
      val action = data.getString("action")
      val content = data.optJSONObject("content")
      val id = if (msg.has("id")) msg.getString("id") else null
      
      // CRITICAL: Post to main thread
      mainHandler.post {
        when (action) {
          "getDeviceInfo" -> {
            val result = JSONObject().apply {
              put("platform", "Android")
              put("version", Build.VERSION.RELEASE)
              put("sdkInt", Build.VERSION.SDK_INT)
            }
            if (id != null) sendResult(id, result)
          }
          
          "trackEvent" -> {
            // Fire-and-forget - no response needed
            val event = content?.optString("event") ?: ""
            trackEvent(event)
          }
          
          else -> {
            if (id != null) sendError(id, "UNKNOWN_ACTION", "Unknown action: $action")
          }
        }
      }
    } catch (e: Exception) {
      Log.e("Bridge", "Error handling message", e)
    }
  }
  
  // Helper: Send result back to web (must run on main thread)
  private fun sendResult(id: String, result: JSONObject) {
    val response = JSONObject().apply {
      put("version", "1.0")
      put("id", id)
      put("result", result)
    }
    val js = "window.bridge._onNativeResponse($response)"
    webView.evaluateJavascript(js, null)
  }
  
  // Helper: Send error back to web (must run on main thread)
  private fun sendError(id: String, code: String, message: String) {
    val response = JSONObject().apply {
      put("version", "1.0")
      put("id", id)
      put("error", JSONObject().apply {
        put("code", code)
        put("message", message)
      })
    }
    val js = "window.bridge._onNativeResponse($response)"
    webView.evaluateJavascript(js, null)
  }
}

// Call web (fire-and-forget)
fun sendEventToWeb(action: String, content: Map<String, Any>) {
  val message = JSONObject().apply {
    put("version", "1.0")
    put("data", JSONObject().apply {
      put("action", action)
      put("content", JSONObject(content))
    })
  }
  webView.post {
    webView.evaluateJavascript("window.bridge._onNativeMessage($message)", null)
  }
}
```

**Critical Android Points:**

1. **Threading**: `@JavascriptInterface` runs on background thread - ALWAYS post to main thread for WebView operations
2. **JSON Format**: Android needs string, iOS takes objects - use `JSON.stringify()` on web side
3. **Security**: Only use with HTTPS or localhost (Android < 4.2 security issue)
4. **Main Thread**: All `evaluateJavascript()` calls MUST run on main thread

### Platform Differences Summary

| Aspect | iOS (WKWebView) | Android (WebView) |
|--------|-----------------|-------------------|
| **Web→Native** | `window.webkit.messageHandlers.bridge.postMessage(obj)` | `window.AndroidBridge.postMessage(JSON.stringify(obj))` |
| **Native→Web** | `webView.evaluateJavaScript(js)` | `webView.evaluateJavascript(js, null)` |
| **Threading** | Usually safe (auto main thread) | **Must post to main thread!** |
| **JSON Format** | Native JavaScript object | **Must stringify!** |
| **Security** | Generally secure | **Requires HTTPS/localhost** |

---

## Common Actions to Implement

Typical actions you'll need:

### Navigation & UI
- `navigate(url, options)` - Navigate to URL
- `goBack()` - Go back
- `close()` - Close webview
- `showToast(message, duration)` - Show toast message
- `showAlert(title, message, buttons)` - Show alert dialog

### Device & System
- `getDeviceInfo()` - Get OS, version, model
- `requestPermission(type)` - Request camera, location, etc.
- `share(content, options)` - Share content
- `copyToClipboard(text)` - Copy to clipboard
- `openUrl(url, external)` - Open URL externally

### Storage
- `getSecureData(key)` - Get from secure storage
- `setSecureData(key, value)` - Store securely
- `removeSecureData(key)` - Remove from storage

### Analytics & Tracking
- `trackEvent(name, properties)` - Track event
- `trackScreen(name, properties)` - Track screen view
- `setUserId(id)` - Set user ID

---

## Testing

### Mock Bridge for Browser Development

```javascript
if (!window.bridge) {
  window.bridge = {
    isReady: true,
    version: "1.0.0-mock",
    
    async ready() {
      console.log('[Mock] Bridge ready');
    },
    
    async call(message, options) {
      const { action, content } = message.data;
      console.log(`[Mock] Call: ${action}`, content);
      
      // Simulate delay
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Return mock data
      switch (action) {
        case 'getDeviceInfo':
          return { platform: 'mock', version: '1.0' };
        case 'getUserProfile':
          return { id: '123', name: 'Mock User' };
        default:
          return { success: true };
      }
    },
    
    on(handler) {
      this._handler = handler;
    },
    
    off() {
      this._handler = null;
    },
    
    setDebug(enabled) {
      console.log(`[Mock] Debug: ${enabled}`);
    }
  };
}
```

---

## Security & Performance

### Security Checklist

- [ ] Validate origin of webview content
- [ ] Whitelist allowed actions on native side
- [ ] Sanitize all input parameters
- [ ] Use HTTPS for web content
- [ ] Don't expose sensitive native APIs
- [ ] Implement rate limiting for bridge calls
- [ ] Never pass credentials through bridge

### Performance Best Practices

- **Minimize calls**: Group related data when possible
- **Keep messages small**: < 100KB ideal, < 1MB max
- **Always async/await**: Never block UI thread
- **Debounce frequent events**: Don't spam bridge
- **For large data**: Use separate transfer mechanism

---

## Implementation Roadmap

### Phase 1: Core (Day 1)
1. Core bridge implementation (`call()`, `on()`)
2. Ready state detection (`isReady`, `ready()`)
3. Timeout handling (default 30s)
4. Basic error handling
5. Mock for browser testing

### Phase 2: Essential Actions (Week 1)
6. Implement 3-5 essential native actions:
   - `getDeviceInfo()` - device metadata
   - `navigate(url)` - navigation  
   - `showToast(message)` - feedback
   - `requestPermission(type)` - permissions
7. Debug logging

### Phase 3: Polish (As Needed)
8. AbortSignal support (optional)
9. Additional actions based on usage
10. Performance optimizations

**That's it.** The entire bridge is ~200 lines of JavaScript. Don't add anything else unless you actually need it.

---

## Why This Approach Works

**The Problem with Most Bridges:**
- Too complex: Multiple methods, event systems, parameter parsing
- Or too simple: No error handling, timeouts, or proper async support
- Versioning nightmares when adding features

**This Design:**
- **~200 lines of JavaScript** - implementable in a day
- **Pure JSON** - bridge doesn't parse, native does
- **Zero versioning issues** - add new actions without touching bridge
- **Production-ready** - timeouts, errors, AbortSignal support
- **Self-documenting** - behavior emerges from usage patterns

The bridge doesn't know or care what actions you're calling - that's between your web and native code. This separation means the bridge code never needs to change, only your action handlers.
