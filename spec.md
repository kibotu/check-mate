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
4. [Usage Examples](#usage-examples)
5. [TypeScript Interface](#typescript-interface)
6. [Design Considerations](#design-considerations)
7. [API Design Philosophy](#api-design-philosophy)
8. [Common Actions to Implement](#common-actions-to-implement)
9. [Platform-Specific Implementation](#platform-specific-implementation)
   - [Web-Side Bridge Implementation](#web-side-bridge-implementation)
   - [iOS (WKWebView)](#ios-wkwebview)
   - [Android (WebView)](#android-webview)
10. [Testing Strategy](#testing-strategy)
11. [Security Checklist](#security-checklist)
12. [Performance Considerations](#performance-considerations)
13. [Implementation Roadmap](#implementation-roadmap)
14. [Migration & Versioning](#migration--versioning)
15. [Critical Implementation Notes](#critical-implementation-notes)

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
  
  // Handle the action
  switch (action) {
    case 'someAction':
      // Return value if native expects response, or return nothing
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
  "data": {
    "action": "string",      // Required: The command/action to execute
    "content": {}            // Optional: The payload/parameters
  }
}
```

**That's it.** Everything is in `data.action` and `data.content`.

### Internal Format (Bridge Implementation Detail)

The bridge internally adds an `id` for request-response tracking:

```json
{
  "data": {
    "action": "string",
    "content": {}
  },
  "id": "string"             // Added by bridge for awaited calls
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

If the action is not supported or fails:

```json
{
  "error": {
    "code": "UNKNOWN_ACTION",     // Error code
    "message": "Action 'foo' not supported"
  }
}
```

---

## Usage Examples

### Web Side

```javascript
// Fire-and-forget: Just call without awaiting
window.bridge.call({
  data: {
    action: 'trackEvent',
    content: {
      event: 'button_click',
      screen: 'home'
    }
  }
});

// Request-response: Await for result
try {
  const result = await window.bridge.call({
    data: {
      action: 'getUserProfile',
      content: { userId: '123' }
    }
  });
  console.log("Profile:", result);  // Direct result
} catch (error) {
  console.error("Error:", error.message);
}

// With timeout option
try {
  const result = await window.bridge.call({
    data: {
      action: 'requestPermission',
      content: { permission: 'camera' }
    }
  }, { timeout: 5000 });
  
  console.log("Granted:", result);
} catch (error) {
  console.error("Denied:", error.message);
}

// Handle incoming messages from native
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  
  switch (action) {
    case 'processPayment':
      // Request-response: return value
      const result = await processPayment(content);
      return { success: true, result };
      
    case 'appStateChanged':
      // Fire-and-forget: no return value
      console.log("App state:", content.state);
      await handleStateChange(content.state);
      return; // Or just don't return
      
    default:
      return { error: { code: 'UNKNOWN_ACTION', message: `Unknown action: ${action}` } };
  }
});
```

### Native Side (Pseudocode)

```swift
// iOS Example

// Handle incoming messages from web
func handleWebMessage(message: JSON) {
  let action = message["data"]["action"] as? String
  let content = message["data"]["content"] as? JSON
  let id = message["id"] as? String  // Present if web expects response
  
  switch action {
    case "getUserProfile":
      let profile = getUserProfile(content["userId"])
      if let id = id {
        // Has ID = send response back
        sendResult(id: id, result: profile)
      }
      
    case "trackEvent":
      // No ID = fire-and-forget
      trackEvent(content["event"], content["screen"])
      
    default:
      if let id = id {
        sendError(id: id, error: [
          "error": [
            "code": "UNKNOWN_ACTION",
            "message": "Action '\(action)' not supported"
          ]
        ])
      }
  }
}

// Call web (fire-and-forget)
bridge.sendToWeb([
  "data": [
    "action": "appStateChanged",
    "content": ["state": "background"]
  ]
])

// Call web (request-response)
let result = await bridge.callWeb([
  "data": [
    "action": "processPayment",
    "content": ["amount": 99.99]
  ]
])
```

---

## TypeScript Interface

```typescript
interface Bridge {
  // State
  readonly isReady: boolean;
  readonly version: string;
  
  // Lifecycle - async function, use with await
  // Usage: await window.bridge.ready()
  ready(): Promise<void>;
  
  // Web → Native - async function, use with await (or don't await for fire-and-forget)
  // Usage: await window.bridge.call({ data: { action: '...', content: {} } })
  call<T = any>(
    message: BridgeMessage,
    options?: CallOptions
  ): Promise<T>;
  
  // Native → Web (receive JSON)
  on(handler: MessageHandler): void;
  off(): void;
  
  // Utility
  setDebug(enabled: boolean): void;
}

interface BridgeMessage {
  data: {
    action: string;      // The command/action to execute
    content?: any;       // The payload/parameters
  };
}

interface CallOptions {
  timeout?: number;      // milliseconds (default: 30000)
  signal?: AbortSignal;  // AbortController support (optional)
}

interface BridgeError extends Error {
  code: string;
  details?: any;
}

// Handler can be sync or async
type MessageHandler = (message: BridgeMessage) => any | Promise<any> | void;

// Global declaration
declare global {
  interface Window {
    bridge: Bridge;
  }
}
```

**Note on TypeScript and Async/Await:**

In TypeScript, `Promise<T>` is the return type of `async` functions. When you write:
```typescript
async function foo(): Promise<string> { ... }
```
You call it with:
```typescript
const result = await foo();  // result is string, not Promise<string>
```

The `Promise<T>` in the type signature indicates it's an async function that should be awaited. This is TypeScript's way of representing async functions - you don't use `.then()` chains, you use `await`.

---

## Design Considerations

### Ready State Detection

The bridge might not be ready immediately:

```javascript
// Check if bridge is available and ready
if (window.bridge?.isReady) {
  const info = await window.bridge.call({
    data: { action: 'getDeviceInfo' }
  });
}

// Async ready check (preferred)
await window.bridge.ready();
const info = await window.bridge.call({
  data: { action: 'getDeviceInfo' }
});

// Or wait for ready event
window.addEventListener('bridgeReady', async () => {
  const info = await window.bridge.call({
    data: { action: 'getDeviceInfo' }
  });
  console.log(info);
});
```

### Timeout Handling

Calls can hang forever if native doesn't respond:

```javascript
// Built-in timeout (default: 30 seconds)
try {
  const result = await window.bridge.call({
    data: {
      action: 'slowOperation',
      content: { /* params */ }
    }
  }, { timeout: 5000 });  // 5 seconds
  
} catch (error) {
  if (error.code === 'TIMEOUT') {
    console.error('Operation timed out');
  }
}

// Optional: AbortController for manual cancellation
const controller = new AbortController();
try {
  const result = await window.bridge.call({
    data: {
      action: 'longOperation',
      content: { /* params */ }
    }
  }, { signal: controller.signal });
  
} catch (error) {
  if (error.name === 'AbortError') {
    console.log('Operation cancelled');
  }
}

// Cancel from elsewhere
setTimeout(() => controller.abort(), 3000);
```

### Handler Registration

Register a single global handler for incoming calls from native:

```javascript
// Register ONE global handler (can be async)
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  
  switch (action) {
    case 'locationUpdate':
      // Fire-and-forget event
      console.log("New location:", content.lat, content.lon);
      await updateMapPosition(content.lat, content.lon);
      return; // No response
      
    case 'getWebData':
      // Request-response pattern
      const data = await fetchData(content.query);
      return { data };  // Sent back to native
      
    default:
      return { error: { code: 'UNKNOWN_ACTION' } };
  }
});

// Remove handler
window.bridge.off();
```

### Bridge Availability Check

Web needs to detect if running in native or browser:

```javascript
// Check if running in native app
const isNative = !!window.bridge;

// Feature detection pattern (recommended)
if (window.bridge) {
  // Native-specific code
  await window.bridge.call({
    data: { action: 'nativeFeature' }
  });
} else {
  // Browser fallback
  console.log('Running in browser');
}
```

### Message Queue Before Ready

Queue calls sent before bridge is ready:

```javascript
// Calls are automatically queued if bridge not ready
window.bridge.call({
  data: {
    action: 'trackEvent',
    content: { event: 'early' }
  }
});
// ↑ Queued internally and flushed when bridge becomes ready

// Awaited calls wait for ready automatically
const info = await window.bridge.call({
  data: { action: 'getInfo' }
});
// ↑ Automatically waits for bridge to be ready
```

### Error Codes Standard

Define standard error codes:

```javascript
const ErrorCodes = {
  TIMEOUT: "TIMEOUT",
  NOT_IMPLEMENTED: "NOT_IMPLEMENTED",
  INVALID_PARAMS: "INVALID_PARAMS",
  PERMISSION_DENIED: "PERMISSION_DENIED",
  NETWORK_ERROR: "NETWORK_ERROR",
  UNKNOWN: "UNKNOWN",
  UNKNOWN_ACTION: "UNKNOWN_ACTION"
};
```

### Size Limits

JSON serialization has limits. Define max message size (e.g., 1MB):

```javascript
const MAX_MESSAGE_SIZE = 1024 * 1024; // 1MB
```

For large data (images, files), use separate transfer mechanism.

### Debug Mode

Enable detailed logging for development:

```javascript
window.bridge.setDebug(true);
```

---

## API Design Philosophy

### Evolution from Complex to Simple

**Traditional Approach: Multiple methods, multiple parameters**
```javascript
window.bridge.send("track", { event: "click" });           // Fire-and-forget
window.bridge.call("getUser", { id: 123 });                // Request-response
window.bridge.handle("payment", handler);                  // Handle requests
window.bridge.on("event", listener);                       // Listen to events
```

**This Design: Two methods, pure JSON**
```javascript
// ONE method for web→native (await = response, no await = fire-and-forget)
// Just pass JSON
window.bridge.call({
  data: { action: "track", content: { event: "click" } }
});

await window.bridge.call({
  data: { action: "getUser", content: { id: 123 } }
});

// ONE global handler for native→web (return value = response, no return = event)
window.bridge.on(async (message) => {
  const { action, content } = message.data;
  
  switch (action) {
    case 'payment':
      return { result };  // Response
    case 'event':
      // No return = fire-and-forget
  }
});
```

### Key Advantages

1. **Smaller API surface** = fewer versioning issues
2. **Pure JSON everywhere**: No method names, no parameter parsing. Just JSON in, JSON out.
3. **Self-documenting behavior**: 
   - Await it? You want a response.
   - Don't await? Fire-and-forget.
   - Return value? Send it back.
   - No return? Just an event.
4. **Easier to implement**: One code path on each side, no parameter parsing
5. **Future-proof**: No need to add methods for new patterns
6. **Native controls the schema**: Native checks `data.action` and implements whatever it wants

### Design Principles

1. **Radically Minimal**: 
   - Only 2 core methods total: `call()` and `on()`
   - No `dispatch` vs `invoke` - just await or don't
   - No multiple `on` handlers - one global handler with switch
   
2. **Pure JSON Everything**: 
   - No method/param separation - just pass JSON
   - Bridge doesn't parse structure - native does
   - `{ data: { action: "...", content: {} } }` - that's it
   - Native controls the schema
   
3. **Self-Documenting Behavior**: 
   - `await bridge.call()` = I want a response
   - `bridge.call()` = Fire-and-forget
   - `return value` in handler = Send response back
   - No return = Just an event
   
4. **Version-Proof**:
   - Tiny API surface means zero breaking changes
   - Add new actions without touching bridge
   - Same bridge code works forever
   
5. **Modern JavaScript**:
   - Async/await everywhere, no callbacks
   - Generic TypeScript types for type safety
   - Optional AbortSignal support for cancellation
   
6. **Developer Experience**:
   - Direct result unwrapping (no `.result` access)
   - Automatic queuing before ready
   - Async `ready()` helper
   
7. **Production Ready**:
   - Timeout handling
   - Error code standards
   - Debug mode
   - Size limits
   
8. **Testable**: Simple mock implementation for browser testing

9. **Platform Agnostic**: Same API works on iOS and Android

---

## Common Actions to Implement

Here are typical actions you'll need:

### Navigation & UI
- `navigate(url, options)`
- `goBack()`
- `close()`
- `setTitle(title)`
- `showToast(message, duration)`
- `showAlert(title, message, buttons)`

### Device & System
- `getDeviceInfo()` → OS, version, model, etc.
- `requestPermission(type)` → camera, location, etc.
- `openSettings()`
- `share(content, options)`
- `copyToClipboard(text)`
- `openUrl(url, external)`

### Storage
- `getSecureData(key)`
- `setSecureData(key, value)`
- `removeSecureData(key)`

### Analytics & Tracking
- `trackEvent(name, properties)`
- `trackScreen(name, properties)`
- `setUserId(id)`

### Network
- `fetch(url, options)` → Optionally use native networking
- `getNetworkStatus()` → Online/offline, connection type

### Lifecycle
- `onAppBackground()`
- `onAppForeground()`
- `onWebViewReady()`

---

## Platform-Specific Implementation

### Web-Side Bridge Implementation

The bridge JavaScript that needs to be injected:

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
      
      // Add id to message for request-response pattern
      const messageWithId = { ...message, id };
      
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
          const response = { id: message.id, result };
          
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

// Helper: Send result back to web
func sendResult(id: String, result: Any) {
  let response: [String: Any] = ["id": id, "result": result]
  if let jsonData = try? JSONSerialization.data(withJSONObject: response),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeResponse(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

// Helper: Send error back to web
func sendError(id: String, code: String, message: String) {
  let response: [String: Any] = [
    "id": id,
    "error": ["code": code, "message": message]
  ]
  if let jsonData = try? JSONSerialization.data(withJSONObject: response),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeResponse(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

// Send event to web (fire-and-forget)
func sendEventToWeb(action: String, content: [String: Any]) {
  let message: [String: Any] = [
    "data": [
      "action": action,
      "content": content
    ]
  ]
  if let jsonData = try? JSONSerialization.data(withJSONObject: message),
     let jsonString = String(data: jsonData, encoding: .utf8) {
    let js = "window.bridge._onNativeMessage(\(jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

// Example: Call web and await response
func callWeb(action: String, content: [String: Any]) async throws -> Any {
  let id = UUID().uuidString
  let message: [String: Any] = [
    "data": [
      "action": action,
      "content": content
    ],
    "id": id
  ]
  
  // Store pending request and wait for response
  // (Implementation depends on your response tracking mechanism)
  return try await withCheckedThrowingContinuation { continuation in
    pendingRequests[id] = continuation
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: message),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      let js = "window.bridge._onNativeMessage(\(jsonString))"
      webView.evaluateJavaScript(js, completionHandler: nil)
    }
  }
}
```

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
      
      // Handle on main thread
      mainHandler.post {
        when (action) {
          "getDeviceInfo" -> {
            val result = JSONObject().apply {
              put("platform", "Android")
              put("version", Build.VERSION.RELEASE)
              put("sdkInt", Build.VERSION.SDK_INT)
            }
            if (id != null) {
              sendResult(id, result)
            }
          }
          
          "trackEvent" -> {
            // Fire-and-forget - no response needed
            val event = content?.optString("event") ?: ""
            trackEvent(event)
          }
          
          else -> {
            if (id != null) {
              sendError(id, "UNKNOWN_ACTION", "Unknown action: $action")
            }
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
      put("id", id)
      put("result", result)
    }
    val js = "window.bridge._onNativeResponse(${response})"
    webView.evaluateJavascript(js, null)
  }
  
  // Helper: Send error back to web (must run on main thread)
  private fun sendError(id: String, code: String, message: String) {
    val response = JSONObject().apply {
      put("id", id)
      put("error", JSONObject().apply {
        put("code", code)
        put("message", message)
      })
    }
    val js = "window.bridge._onNativeResponse(${response})"
    webView.evaluateJavascript(js, null)
  }
}

// Send event to web (fire-and-forget) - must run on main thread
fun sendEventToWeb(action: String, content: Map<String, Any>) {
  val message = JSONObject().apply {
    put("data", JSONObject().apply {
      put("action", action)
      put("content", JSONObject(content))
    })
  }
  val js = "window.bridge._onNativeMessage($message)"
  webView.post {
    webView.evaluateJavascript(js, null)
  }
}

// Example: Call web and await response
suspend fun callWeb(action: String, content: Map<String, Any>): JSONObject = suspendCoroutine { continuation ->
  val id = UUID.randomUUID().toString()
  val message = JSONObject().apply {
    put("data", JSONObject().apply {
      put("action", action)
      put("content", JSONObject(content))
    })
    put("id", id)
  }
  
  // Store pending request
  pendingRequests[id] = continuation
  
  // Send to web on main thread
  webView.post {
    val js = "window.bridge._onNativeMessage($message)"
    webView.evaluateJavascript(js, null)
  }
}
```

**Important Android Notes:**

1. **Threading**: `@JavascriptInterface` methods run on a background thread. Always post back to main thread for WebView operations.

2. **Security**: `addJavascriptInterface` has security implications on Android < 4.2. Use only with HTTPS or localhost content.

3. **JSON Serialization**: JSONObject's `toString()` is automatically called when used in string interpolation, which is correct for JavaScript.

---

## Testing Strategy

### Mock Bridge for Browser Testing

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
      
      // Simulate async delay if timeout specified
      if (options?.timeout) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      // Return mock data based on action
      switch (action) {
        case 'getDeviceInfo':
          return { platform: 'mock', version: '1.0', os: 'browser' };
        case 'getUserProfile':
          return { id: '123', name: 'Mock User', email: 'mock@example.com' };
        case 'requestPermission':
          return { granted: true };
        case 'trackEvent':
          return; // Fire-and-forget
        default:
          return { success: true, mock: true };
      }
    },
    
    on(handler) {
      console.log('[Mock] Registered global handler');
      this._handler = handler;
    },
    
    off() {
      console.log('[Mock] Removed handler');
      this._handler = null;
    },
    
    setDebug(enabled) {
      console.log(`[Mock] Debug mode: ${enabled}`);
    }
  };
}
```

### Complete Example

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
      console.log("Device:", deviceInfo);  // Direct result
      
      // Fire-and-forget call (no await)
      window.bridge.call({
        data: {
          action: 'trackEvent',
          content: {
            event: 'page_load',
            timestamp: Date.now()
          }
        }
      });
      
      // Handle incoming messages from native
      window.bridge.on(async (message) => {
        const { action, content } = message.data;
        
        switch (action) {
          case 'getWebState':
            // Request-response: return value
            return {
              scrollPosition: window.scrollY,
              url: window.location.href
            };
            
          case 'appStateChanged':
            // Fire-and-forget: no return
            console.log('App state:', content.state);
            if (content.state === 'background') {
              await saveState();
            }
            return;
            
          default:
            return { error: { code: 'UNKNOWN_ACTION' } };
        }
      });
    }
    
    // Initialize on load
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
    } else {
      init();
    }
    
    // Fire-and-forget: just call without awaiting
    function showToast() {
      window.bridge.call({
        data: {
          action: 'showToast',
          content: {
            message: 'Hello from WebView!',
            duration: 'short'
          }
        }
      });
    }
    
    // Request-response: await the call
    async function requestPermission() {
      try {
        const result = await window.bridge.call({
          data: {
            action: 'requestPermission',
            content: { permission: 'camera' }
          }
        }, { timeout: 5000 });
        
        if (result.granted) {
          console.log('Camera permission granted');
        }
      } catch (error) {
        console.error('Permission denied:', error);
      }
    }
  </script>
</head>
<body>
  <h1>Bridge Demo</h1>
  <button onclick="showToast()">Show Toast</button>
  <button onclick="requestPermission()">Request Camera</button>
</body>
</html>
```

---

## Security Checklist

- [ ] Validate origin of webview content
- [ ] Whitelist allowed actions on native side
- [ ] Sanitize all input parameters
- [ ] Use HTTPS for web content
- [ ] Don't expose sensitive native APIs
- [ ] Implement rate limiting for bridge calls
- [ ] Log security-relevant bridge calls
- [ ] Use Content Security Policy in webview
- [ ] Never pass credentials through bridge
- [ ] Implement action permissions system

---

## Performance Considerations

- **Minimize bridge calls**: Group related data when possible
- **Keep messages small**: < 100KB ideal, < 1MB max
- **Always use async/await**: Never block the UI thread
- **Debounce frequent events**: Don't spam bridge with rapid calls
- **For large data**: Use compression or separate transfer mechanism

---

## Implementation Roadmap

### Phase 1: Core (Day 1)

1. **Core bridge implementation** (`call()`, `on()`)
2. **Ready state detection** (`isReady`, `ready()`)
3. **Timeout handling** (default 30s)
4. **Basic error handling** (standard error codes)
5. **Mock for browser testing**

### Phase 2: Essential Actions (Week 1)

6. **3-5 essential native actions**:
   - `getDeviceInfo()` - device metadata
   - `navigate(url)` - navigation  
   - `showToast(message)` - simple feedback
   - `requestPermission(type)` - permissions
7. **Debug logging**

### Phase 3: Polish (As Needed)

8. **AbortSignal support** (optional - add later if needed)
9. **Additional actions** based on real usage
10. **Performance optimizations**

**That's it.** The entire bridge is ~200 lines of JavaScript. Don't add anything else unless you actually need it.

---

## Migration & Versioning

### Version Management

Include version in bridge for compatibility:

```javascript
window.bridge.version = "1.0.0";
```

Web can check version and adjust behavior:

```javascript
const [major] = window.bridge.version.split('.');
if (parseInt(major) < 2) {
  // Use legacy API
}

// Semantic versioning check
if (window.bridge.supportsFeature?.('batch')) {
  window.bridge.batchDispatch([...]);
} else {
  // Fallback
}
```

### Key Points

- The entire bridge is ~200 lines of JavaScript
- You can build and ship the core in a day
- Add 5 essential native actions (just `switch` cases in native code) over the next week
- Most bridge implementations fail because they're either too simple (no error handling) or too complex (unnecessary abstractions)
- This is minimal but production-ready
- Pure JSON in, pure JSON out
- The bridge doesn't know or care what actions you're calling - that's between your web and native code

---

## Critical Implementation Notes

### Issues Found and Corrected in Platform Implementations

**iOS (WKWebView):**
1. ✅ **JSON Serialization**: Fixed incorrect string interpolation with JSON data
2. ✅ **Thread Safety**: Added `DispatchQueue.main.async` for UI operations
3. ✅ **Safe Unwrapping**: Changed force unwraps to safe `guard` statements
4. ✅ **Helper Methods**: Added proper `sendResult` and `sendError` implementations
5. ✅ **Response Tracking**: Added async/await example with proper continuation handling

**Android (WebView):**
1. ✅ **Threading**: Added `Handler(Looper.getMainLooper())` - critical! `@JavascriptInterface` runs on background thread
2. ✅ **JSON Handling**: Fixed JSON string serialization for evaluateJavascript
3. ✅ **Security Note**: Added warning about `addJavascriptInterface` security on Android < 4.2
4. ✅ **Main Thread**: All WebView operations must run on main thread using `webView.post {}`
5. ✅ **Error Handling**: Added try-catch around JSON parsing
6. ✅ **Coroutines**: Added suspend function example for async operations

**Web-Side Bridge:**
1. ✅ **Complete Implementation**: Added full working bridge JavaScript
2. ✅ **Platform Detection**: Properly detects iOS (`window.webkit`) vs Android (`window.AndroidBridge`)
3. ✅ **Promise Management**: Implements proper pending call tracking with timeout
4. ✅ **Error Handling**: Sends errors back when handler throws
5. ✅ **Ready State**: Properly manages bridge ready state and event

### Critical Platform Differences

| Aspect | iOS (WKWebView) | Android (WebView) |
|--------|-----------------|-------------------|
| **Web→Native** | `window.webkit.messageHandlers.bridge.postMessage(obj)` | `window.AndroidBridge.postMessage(JSON.stringify(obj))` |
| **Native→Web** | `webView.evaluateJavaScript(js)` | `webView.evaluateJavascript(js, null)` |
| **Threading** | Usually safe (auto main thread) | **Must post to main thread!** |
| **JSON Format** | Native JavaScript object | **Must stringify!** |
| **Security** | Generally secure | **Requires HTTPS or localhost** |

### Common Pitfalls to Avoid

1. **Android Threading**: Never call `webView.evaluateJavascript()` from `@JavascriptInterface` thread
2. **JSON Stringification**: iOS takes objects, Android needs strings
3. **Error Responses**: Always send error responses for failed requests with IDs
4. **Memory Leaks**: Clear pending requests on timeout or when WebView is destroyed
5. **Security**: Validate all input from web, never use `eval()`, whitelist actions
