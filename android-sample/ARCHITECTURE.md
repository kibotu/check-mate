# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MainActivity.kt                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                         WebView                             │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              JavaScript Environment                   │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌─────────────────────────────────────────────┐     │  │ │
│  │  │  │          bridge.js (Web Side)               │     │  │ │
│  │  │  │                                              │     │  │ │
│  │  │  │  • window.bridge.call()                     │     │  │ │
│  │  │  │  • window.bridge.on()                       │     │  │ │
│  │  │  │  • Request tracking                         │     │  │ │
│  │  │  │  • Timeout handling                         │     │  │ │
│  │  │  └─────────────────────────────────────────────┘     │  │ │
│  │  │                        ↕                              │  │ │
│  │  │                   JSON Messages                       │  │ │
│  │  │                        ↕                              │  │ │
│  │  │  ┌─────────────────────────────────────────────┐     │  │ │
│  │  │  │         Your Web App (index.html)          │     │  │ │
│  │  │  │                                              │     │  │ │
│  │  │  │  • UI Components                            │     │  │ │
│  │  │  │  • Business Logic                           │     │  │ │
│  │  │  │  • Event Handlers                           │     │  │ │
│  │  │  └─────────────────────────────────────────────┘     │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               ↕                                  │
│                window.AndroidBridge.postMessage()                │
│            (@JavascriptInterface - Background Thread)            │
│                               ↕                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │            BridgeInterface.kt (Native Side)                 │ │
│  │                                                              │ │
│  │  • postMessage() - Receive from web                         │ │
│  │  • handleAction() - Route to handlers                       │ │
│  │  • sendResult() - Send response                             │ │
│  │  • sendEventToWeb() - Push events                           │ │
│  │  • callWeb() - Request-response to web                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               ↕                                  │
│                    Main Thread Dispatcher                        │
│                               ↕                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Action Handlers                           │ │
│  │                                                              │ │
│  │  • getDeviceInfo      • showToast                           │ │
│  │  • trackEvent         • requestPermission                   │ │
│  │  • navigate           • getSecureData                       │ │
│  │  • setSecureData      • [Your Actions]                      │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Message Flow

### 1. Web → Native (Request-Response)

```
Web Side (JavaScript)                Native Side (Kotlin)
─────────────────────                ────────────────────

1. User clicks button
   ↓
2. Call bridge.call()
   await window.bridge.call({
     data: {
       action: 'getDeviceInfo'
     }
   })
   ↓
3. Add ID, store promise
   { id: "abc123", data: {...} }
   ↓
4. Send via AndroidBridge.postMessage()
   ──────────────────────────→  5. @JavascriptInterface receives
                                    postMessage(jsonString)
                                    ↓
                                 6. Parse JSON, extract action
                                    ↓
                                 7. Post to main thread
                                    mainHandler.post { ... }
                                    ↓
                                 8. handleAction("getDeviceInfo")
                                    ↓
                                 9. Collect device info
                                    ↓
                                10. sendResult(id, data)
                                    ↓
                                11. evaluateJavascript()
12. _onNativeResponse() called ←──────────────────────────
   ↓
13. Match ID, resolve promise
   ↓
14. Return result to caller
   ↓
15. Update UI
```

### 2. Web → Native (Fire-and-Forget)

```
Web Side                             Native Side
────────                             ───────────

1. Call bridge.call() (no await)
   window.bridge.call({
     data: {
       action: 'trackEvent',
       content: { event: 'click' }
     }
   })
   ↓
2. Send to native (no ID)
   ──────────────────────────→  3. Receive in postMessage()
                                    ↓
                                 4. Handle action
                                    trackEvent(...)
                                    ↓
                                 5. No response sent
                                    (no ID present)
   
6. Continue execution
   (doesn't wait)
```

### 3. Native → Web (Event)

```
Native Side                          Web Side
───────────                          ────────

1. Something happens (e.g., timer)
   ↓
2. Call sendEventToWeb()
   bridge.sendEventToWeb(
     "nativeEvent",
     mapOf("message" to "Hi!")
   )
   ↓
3. Build JSON (no ID)
   { data: { action: "...", content: {...} } }
   ↓
4. evaluateJavascript()
   ──────────────────────────→  5. _onNativeMessage() called
                                    ↓
                                 6. Route to handler
                                    window.bridge.on(handler)
                                    ↓
                                 7. Handler processes
                                    console.log(message)
                                    ↓
                                 8. No response (no ID)
```

### 4. Native → Web (Request-Response)

```
Native Side                          Web Side
───────────                          ────────

1. Need data from web
   ↓
2. Call callWeb()
   val result = bridge.callWeb(
     "getWebState",
     mapOf("query" to "state")
   )
   ↓
3. Generate ID, store continuation
   { id: "xyz789", data: {...} }
   ↓
4. evaluateJavascript()
   ──────────────────────────→  5. _onNativeMessage() called
                                    ↓
                                 6. Route to handler
                                    ↓
                                 7. Handler returns data
                                    return { scrollY: 100 }
                                    ↓
                                 8. Bridge adds ID to response
                                    { id: "xyz789", result: {...} }
                                    ↓
                                 9. Send via postMessage()
10. handleWebResponse() ←──────────────────────────
   ↓
11. Match ID, resume continuation
   ↓
12. Return result to caller
```

## Threading Model

```
┌─────────────────────────────────────────────────────┐
│                 JavaScript Thread                    │
│                  (WebView Engine)                    │
│                                                       │
│  • Runs all JavaScript code                          │
│  • Single-threaded event loop                        │
│  • window.bridge methods execute here                │
└─────────────────────────────────────────────────────┘
                         ↓
         window.AndroidBridge.postMessage()
                         ↓
┌─────────────────────────────────────────────────────┐
│              Background Thread ⚠️                    │
│           (@JavascriptInterface thread)              │
│                                                       │
│  • postMessage() executes here                       │
│  • CANNOT call WebView methods directly              │
│  • Must post to main thread                          │
└─────────────────────────────────────────────────────┘
                         ↓
              mainHandler.post { ... }
                         ↓
┌─────────────────────────────────────────────────────┐
│                   Main Thread                        │
│                  (UI Thread)                         │
│                                                       │
│  • All WebView operations                            │
│  • evaluateJavascript()                              │
│  • UI updates (Toast, etc.)                          │
│  • Action handlers                                   │
└─────────────────────────────────────────────────────┘
```

## Data Flow

### Message Structure

```javascript
// Web → Native
{
  "data": {
    "action": "actionName",      // Required: what to do
    "content": {                 // Optional: parameters
      "key": "value"
    }
  },
  "id": "abc123"                 // Added by bridge if response expected
}

// Native → Web (Response)
{
  "id": "abc123",                // Matches request ID
  "result": {                    // Success response
    "key": "value"
  }
}

// Native → Web (Error)
{
  "id": "abc123",
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description"
  }
}

// Native → Web (Event)
{
  "data": {
    "action": "eventName",
    "content": {
      "key": "value"
    }
  }
  // No ID = fire-and-forget
}
```

## Component Responsibilities

### bridge.js (Web Side)
- ✅ Provide simple API: `call()`, `on()`, `ready()`
- ✅ Generate unique IDs for request-response
- ✅ Track pending requests
- ✅ Handle timeouts
- ✅ Match responses to requests
- ✅ Platform detection (Android/iOS)
- ✅ Error handling

### BridgeInterface.kt (Native Side)
- ✅ Receive messages from JavaScript
- ✅ Handle threading (background → main)
- ✅ Route actions to handlers
- ✅ Execute actions
- ✅ Send responses back
- ✅ Push events to web
- ✅ Request-response to web (with coroutines)

### MainActivity.kt
- ✅ Setup WebView
- ✅ Inject bridge
- ✅ Enable JavaScript
- ✅ Configure security
- ✅ Handle lifecycle

## Design Patterns

### 1. Request-Response Pattern
```
Caller awaits → Bridge adds ID → Execute → Return result
```

### 2. Fire-and-Forget Pattern
```
Caller doesn't await → No ID added → Execute → No response
```

### 3. Observer Pattern
```
Register handler → Events arrive → Handler processes
```

### 4. Promise Pattern (Web)
```
Async/await API → Automatic promise handling
```

### 5. Coroutine Pattern (Native)
```
Suspend functions → Non-blocking async operations
```

## Security Layers

```
┌────────────────────────────────────┐
│      Content Security Policy       │  ← Web page restrictions
├────────────────────────────────────┤
│      Action Whitelisting           │  ← Only known actions allowed
├────────────────────────────────────┤
│      Input Validation              │  ← Sanitize all inputs
├────────────────────────────────────┤
│      Permission Checks             │  ← Verify permissions per action
├────────────────────────────────────┤
│      Thread Safety                 │  ← Prevent race conditions
├────────────────────────────────────┤
│      Timeout Protection            │  ← Prevent hanging requests
└────────────────────────────────────┘
```

## Performance Considerations

### Optimization Points
1. **JSON Serialization**: Minimize message size
2. **Batching**: Group multiple calls when possible
3. **Caching**: Cache device info, permissions
4. **Debouncing**: Throttle frequent events
5. **Lazy Loading**: Load web content on demand

### Bottlenecks to Avoid
- ❌ Large JSON payloads (> 1MB)
- ❌ Synchronous operations on main thread
- ❌ Excessive bridge calls (> 100/sec)
- ❌ Memory leaks from pending requests
- ❌ Blocking operations in handlers

## Extension Points

Add your own functionality by extending:

1. **Actions**: Add cases in `handleAction()`
2. **Events**: Call `sendEventToWeb()` from anywhere
3. **Permissions**: Integrate Android permission APIs
4. **Storage**: Connect to SharedPreferences/KeyStore
5. **Analytics**: Integrate Firebase/Amplitude
6. **Network**: Add REST API calls
7. **Camera**: Integrate camera/photo APIs

---

This architecture provides a **solid foundation** for building sophisticated hybrid apps while maintaining **simplicity** and **type safety**. 🏗️

