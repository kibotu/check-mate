# JavaScript ↔ Native Bridge

A lightweight, promise-based bridge for bidirectional communication between web content and native code. The bridge exposes a global `window.bridge` object supporting both request/response patterns and event-style messaging.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Core API](#core-api)
- [Actions Reference](#actions-reference)
  - [Device & System](#device--system)
  - [UI Actions](#ui-actions)
  - [Navigation Controls](#navigation-controls)
  - [Haptic Feedback](#haptic-feedback)
  - [Page Navigation](#page-navigation)
  - [System Actions](#system-actions)
  - [Lifecycle Events](#lifecycle-events)
  - [Push Notifications](#push-notifications)
  - [Secure Storage](#secure-storage)
  - [Analytics](#analytics)
- [Native → Web Events](#native--web-events)
- [Error Handling](#error-handling)
- [Schema Versioning](#schema-versioning)
- [Platform Support](#platform-support)
- [Best Practices](#best-practices)

---

## Quick Start

```js
// 1. Wait for the bridge to be ready
await window.bridge.ready();

// 2. Optional: Enable debug logging
window.bridge.setDebug(true);

// 3. Set up event listener for native → web messages
window.bridge.on((message) => {
  const { action, content } = message.data || {};
  if (action === 'onPushNotification') {
    // Handle push notification
    console.log('Push received:', content);
  }
  if (action === 'lifecycle') {
    console.log('Lifecycle event:', content.event); // 'focused' or 'defocused'
  }
});

// 4. Make calls to native
try {
  const info = await window.bridge.call({
    data: { action: 'deviceInfo' }
  });
  console.log('Device:', info.platform, info.model);
} catch (error) {
  console.error('Bridge error:', error.message);
}
```

**Legacy support:** You can also listen for the `bridgeReady` event:
```js
window.addEventListener('bridgeReady', () => {
  // bridge is ready; window.bridge is now available
});
```

---

## Core API

### `bridge.ready(): Promise<void>`
Resolves when the bridge is fully initialized. **Always call this before using the bridge.**

```js
await window.bridge.ready();
```

### `bridge.setDebug(enabled: boolean): void`
Enables or disables verbose JavaScript-side logging for debugging.

```js
window.bridge.setDebug(true);  // Enable debug logs
```

### `bridge.call(message, options?): Promise<any>`
Sends a message to native and returns a promise that resolves with the response.

**Parameters:**
- `message` (required):
  ```js
  {
    data: {
      action: string,    // required: the action to perform
      content?: object   // optional: action-specific data
    }
  }
  ```
- `options` (optional):
  ```js
  {
    timeout?: number  // milliseconds; default: 30000 (30 seconds)
  }
  ```

**Example:**
```js
const result = await window.bridge.call(
  { data: { action: 'deviceInfo' } },
  { timeout: 5000 }
);
```

### `bridge.on(handler: (message) => any): void`
Registers a handler to receive messages from native. The handler can optionally return a value that will be sent back to native.

```js
window.bridge.on((message) => {
  const { action, content } = message.data || {};
  console.log('Received from native:', action, content);
  return { status: 'received' }; // optional response
});
```

### `bridge.schemaVersion: number` (read-only)
The schema version number set by native. This is automatically attached to every message you send.

```js
console.log('Schema version:', window.bridge.schemaVersion);
```

---

## Actions Reference

All actions follow the same pattern:

```js
await window.bridge.call({
  data: {
    action: 'actionName',
    content: { /* action-specific fields */ }
  }
}, { timeout: 5000 }); // optional timeout
```

### Device & System

#### `deviceInfo`
Returns device and app information.

```js
const info = await bridge.call({
  data: { action: 'deviceInfo' }
});

// Response:
// {
//   platform: 'iOS' | 'Android',
//   osVersion: '17.0',
//   sdkVersion: '33',
//   manufacturer: 'Apple' | 'Samsung',
//   model: 'iPhone 15 Pro',
//   appVersion: '1.2.3'
// }
```

#### `networkState`
Returns current network connectivity status.

```js
const status = await bridge.call({
  data: { action: 'networkState' }
});

// Response: { connected: boolean, type?: 'wifi' | 'cellular' | 'ethernet' }
```

#### `openSettings`
Opens the system settings app (where supported by the platform).

```js
await bridge.call({
  data: { action: 'openSettings' }
});
```

---

### UI Actions

#### `showToast`
Displays a native toast notification.

```js
await bridge.call({
  data: {
    action: 'showToast',
    content: {
      message: 'Hello from WebView! 👋',  // required
      duration: 'short' // optional: 'short' | 'long' (default: 'short')
    }
  }
});
```

#### `showAlert`
Shows a native alert dialog.

```js
await bridge.call({
  data: {
    action: 'showAlert',
    content: {
      title: 'Alert Title',              // required
      message: 'This is the message',    // required
      buttons: ['OK', 'Cancel']          // optional: button labels
    }
  }
});
```

---

### Navigation Controls

#### `topNavigation`
Controls the top navigation bar appearance.

```js
await bridge.call({
  data: {
    action: 'topNavigation',
    content: {
      isVisible: true,                 // optional: show/hide the bar
      title: 'Screen Title',           // optional: set title (null to hide when logo is shown)
      showUpArrow: false,              // optional: back/up arrow
      showDivider: true,               // optional: bottom divider line
      showLogo: false,                 // optional: show app logo
      showProfileIconWidget: false     // optional: profile icon
    }
  }
});
```

**Examples:**
```js
// Hide the entire top navigation
await bridge.call({
  data: { action: 'topNavigation', content: { isVisible: false } }
});

// Show navigation with logo (hide title)
await bridge.call({
  data: {
    action: 'topNavigation',
    content: {
      isVisible: true,
      title: null,
      showLogo: true
    }
  }
});

// Update just the title (keep other settings)
await bridge.call({
  data: {
    action: 'topNavigation',
    content: { title: 'New Title' }
  }
});
```

#### `bottomNavigation`
Controls the bottom navigation bar visibility.

```js
await bridge.call({
  data: {
    action: 'bottomNavigation',
    content: { isVisible: true }  // required: true or false
  }
});
```

#### `systemBars`
Controls system UI bars (status bar and system navigation bar).

⚠️ **Platform limitation:** This action is **Android-only**. iOS does not support controlling system bars due to platform limitations.

```js
await bridge.call({
  data: {
    action: 'systemBars',
    content: {
      showStatusBar: true,          // optional: show/hide status bar
      showSystemNavigation: true    // optional: show/hide system navigation
    }
  }
});

// Hide all system bars (fullscreen mode on Android)
await bridge.call({
  data: {
    action: 'systemBars',
    content: {
      showStatusBar: false,
      showSystemNavigation: false
    }
  }
});
```

---

### Haptic Feedback

#### `haptic`
Triggers haptic/vibration feedback.

```js
await bridge.call({
  data: {
    action: 'haptic',
    content: { vibrate: true }  // required
  }
});

// Multiple vibrations
for (let i = 0; i < 3; i++) {
  await bridge.call({
    data: { action: 'haptic', content: { vibrate: true } }
  });
  await new Promise(resolve => setTimeout(resolve, 200));
}
```

---

### Page Navigation

#### `navigation`
Handles URL navigation (internal or external) and back navigation.

**Open URL internally (in-app):**
```js
await bridge.call({
  data: {
    action: 'navigation',
    content: {
      url: 'https://www.check24.de',
      external: false
    }
  }
});
```

**Open URL externally (system browser):**
```js
await bridge.call({
  data: {
    action: 'navigation',
    content: {
      url: 'https://www.check24.de',
      external: true
    }
  }
});
```

**Navigate back:**
```js
await bridge.call({
  data: {
    action: 'navigation',
    content: { goBack: true }
  }
});
```

---

### System Actions

#### `copyToClipboard`
Copies text to the system clipboard.

```js
await bridge.call({
  data: {
    action: 'copyToClipboard',
    content: {
      text: 'Text to copy'  // required
    }
  }
});
```

---

### Lifecycle Events

#### `lifecycleEvents`
Enables or disables lifecycle event notifications from native (focus/defocus events).

```js
// Enable lifecycle events
await bridge.call({
  data: {
    action: 'lifecycleEvents',
    content: { enable: true }  // required: true or false
  }
});

// Then listen for events via bridge.on()
window.bridge.on((message) => {
  const { action, content } = message.data || {};
  if (action === 'lifecycle') {
    if (content?.event === 'focused') {
      console.log('Screen gained focus - refresh data');
    } else if (content?.event === 'defocused') {
      console.log('Screen lost focus - pause work');
    }
  }
});

// Disable lifecycle events
await bridge.call({
  data: {
    action: 'lifecycleEvents',
    content: { enable: false }
  }
});
```

**Supported on:** iOS and Android

---

### Push Notifications

#### `refresh`
Triggers a refresh command (optional, web-initiated).

```js
await bridge.call({
  data: {
    action: 'refresh',
    content: { command: 'refresh' }  // optional
  }
});
```

#### Receiving Push Notifications from Native

Native automatically sends push notification events to your web app. Listen for them with `bridge.on()`:

```js
window.bridge.on((message) => {
  const { action, content } = message.data || {};
  
  if (action === 'onPushNotification') {
    console.log('Push notification received:', content);
    
    // Example: navigate to a URL from the push
    if (content?.url) {
      window.location.href = content.url;
    }
    
    // Return acknowledgment to native (optional)
    return { status: 'received', handled: true };
  }
});
```

**Note:** Native listens to the messaging service and pushes events to your web app when push notifications arrive.

---

### Secure Storage

Store sensitive data in native secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).

#### `saveSecureData`
Saves a key-value pair securely.

```js
await bridge.call({
  data: {
    action: 'saveSecureData',
    content: {
      key: 'auth_token',        // required
      value: 'abc123xyz'        // required
    }
  }
});
```

#### `loadSecureData`
Loads a value by key from secure storage.

```js
const result = await bridge.call({
  data: {
    action: 'loadSecureData',
    content: { key: 'auth_token' }  // required
  }
});

// Response: { value?: string }
if (result.value) {
  console.log('Token:', result.value);
} else {
  console.log('No value found for key');
}
```

#### `removeSecureData`
Removes a key-value pair from secure storage.

```js
await bridge.call({
  data: {
    action: 'removeSecureData',
    content: { key: 'auth_token' }  // required
  }
});
```

---

### Analytics

Analytics actions are **fire-and-forget**: you don't need to await the result, and no response is expected.

#### `trackEvent`
Logs a custom event to analytics.

```js
bridge.call({
  data: {
    action: 'trackEvent',
    content: {
      event: 'button_click',              // required
      params: {                            // optional
        button_name: 'checkout',
        screen: 'product_detail',
        timestamp: new Date().toISOString()
      }
    }
  }
});
```

#### `trackScreen`
Logs a screen view to analytics.

```js
bridge.call({
  data: {
    action: 'trackScreen',
    content: {
      screenName: 'Product Detail',       // required
      screenClass: 'ProductDetailScreen'  // optional
    }
  }
});
```

---

## Native → Web Events

Native can send events to your web app. Register a single handler with `bridge.on()` and route based on the `action` field:

```js
window.bridge.on((message) => {
  const { action, content } = message.data || {};
  
  switch (action) {
    case 'lifecycle':
      if (content?.event === 'focused') {
        // Screen gained focus
      } else if (content?.event === 'defocused') {
        // Screen lost focus
      }
      break;
      
    case 'onPushNotification':
      // Handle push notification
      console.log('Push:', content);
      break;
      
    case 'notification':
      // General notification from native
      console.log('Notification:', content?.message);
      break;
      
    case 'ping':
      // Respond to ping from native
      return { pong: true, timestamp: Date.now() };
      
    default:
      console.log('Unknown action from native:', action);
  }
  
  // Optionally return a response
  return { status: 'received', handled: true };
});
```

**Best practice:** Subscribe to `bridge.on()` **once** during initialization and route all events through a single handler.

---

## Error Handling

All bridge calls return promises. Use try-catch to handle errors gracefully:

```js
try {
  const info = await bridge.call(
    { data: { action: 'deviceInfo' } },
    { timeout: 5000 }
  );
  console.log('Success:', info);
} catch (error) {
  // error.message may contain:
  // - 'Request timeout after 5000ms'
  // - Native error messages
  console.error('Bridge error:', error.message);
  
  // Provide fallback behavior
  if (error.message.includes('timeout')) {
    console.warn('Bridge timed out - using fallback');
  }
}
```

**Timeout behavior:**
- Default timeout: 30 seconds (30000ms)
- You can customize per call: `{ timeout: 5000 }`
- If native doesn't respond in time, the promise rejects with a timeout error

---

## Schema Versioning

The bridge uses a simple integer schema version (1, 2, 3...) that increments on breaking changes. The version is **read-only** and set by native.

### Checking the Version

```js
const version = window.bridge.schemaVersion;
console.log('Bridge schema version:', version);
```

### Version Gating

Use version gating to support multiple versions gracefully:

```js
const version = window.bridge.schemaVersion;

if (version >= 2) {
  // Use newer APIs available in v2+
  await bridge.call({
    data: { action: 'newFeatureInV2', content: { ... } }
  });
} else {
  // Fall back to v1 behavior
  console.log('Using legacy v1 APIs');
  await bridge.call({
    data: { action: 'legacyFeature', content: { ... } }
  });
}
```

### Version Mismatch Behavior

- **Web uses older version than native supports:** ✅ Works fine (backward compatible)
- **Web uses same version as native:** ✅ Works fine
- **Web sends higher version than native supports:** ⚠️ Native silently ignores the call; your call will timeout

**Why silent ignore?** This allows web apps to be deployed ahead of native apps. The web app can detect the timeout and fall back to older APIs.

### How Versioning Works

Every message you send automatically includes the schema version:

```js
// You send:
{ data: { action: 'deviceInfo' } }

// Bridge adds version and sends to native:
{
  version: 1,                     // automatically added
  id: "msg_12345",                // unique message ID
  data: { action: 'deviceInfo' }
}
```

**You cannot override the version from JavaScript** - it's always set by native via `window.bridge.schemaVersion`.

---

## Platform Support

| Action | iOS | Android | Notes |
|--------|-----|---------|-------|
| `deviceInfo` | ✅ | ✅ | |
| `networkState` | ✅ | ✅ | |
| `openSettings` | ✅ | ✅ | |
| `showToast` | ✅ | ✅ | |
| `showAlert` | ✅ | ✅ | |
| `topNavigation` | ✅ | ✅ | |
| `bottomNavigation` | ✅ | ✅ | |
| `systemBars` | ❌ | ✅ | **iOS limitation:** iOS does not support controlling system bars |
| `haptic` | ✅ | ✅ | |
| `navigation` | ✅ | ✅ | |
| `copyToClipboard` | ✅ | ✅ | |
| `lifecycleEvents` | ✅ | ✅ | Focus/defocus events work on both platforms |
| `refresh` | ✅ | ✅ | |
| `onPushNotification` | ✅ | ✅ | Push events from native |
| `saveSecureData` | ✅ | ✅ | Keychain (iOS), EncryptedSharedPreferences (Android) |
| `loadSecureData` | ✅ | ✅ | |
| `removeSecureData` | ✅ | ✅ | |
| `trackEvent` | ✅ | ✅ | Fire-and-forget |
| `trackScreen` | ✅ | ✅ | Fire-and-forget |

---

## Best Practices

### 1. Always Wait for Bridge Ready
```js
// ✅ Good
await window.bridge.ready();
const info = await bridge.call({ data: { action: 'deviceInfo' } });

// ❌ Bad
const info = await bridge.call({ data: { action: 'deviceInfo' } }); // May fail if bridge not ready
```

### 2. Set Reasonable Timeouts
```js
// ✅ Good - set timeout for better UX
try {
  await bridge.call(
    { data: { action: 'deviceInfo' } },
    { timeout: 5000 }
  );
} catch (error) {
  // Handle timeout gracefully
}

// ❌ Bad - using default 30s timeout for quick operations
await bridge.call({ data: { action: 'deviceInfo' } });
```

### 3. Use Version Gating for New Features
```js
// ✅ Good
if (window.bridge.schemaVersion >= 2) {
  await bridge.call({ data: { action: 'newFeature' } });
} else {
  console.log('Feature not available in this version');
}

// ❌ Bad - no version check
await bridge.call({ data: { action: 'newFeature' } }); // May timeout on older native versions
```

### 4. Fire-and-Forget for Analytics
```js
// ✅ Good - no await needed
bridge.call({
  data: { action: 'trackEvent', content: { event: 'page_view' } }
});

// ❌ Bad - unnecessary await slows down your code
await bridge.call({
  data: { action: 'trackEvent', content: { event: 'page_view' } }
});
```

### 5. Subscribe to Events Once
```js
// ✅ Good - subscribe once during initialization
await window.bridge.ready();
window.bridge.on((message) => {
  // Route all events through one handler
  const { action, content } = message.data || {};
  routeEvent(action, content);
});

// ❌ Bad - subscribing multiple times
button1.onclick = () => {
  window.bridge.on(handleMessage); // Don't do this in event handlers
};
```

### 6. Handle Errors Gracefully
```js
// ✅ Good
try {
  const result = await bridge.call({ data: { action: 'deviceInfo' } });
  console.log(result);
} catch (error) {
  console.error('Bridge error:', error.message);
  // Provide fallback
  const fallbackData = getDefaultDeviceInfo();
}

// ❌ Bad - no error handling
const result = await bridge.call({ data: { action: 'deviceInfo' } });
console.log(result.platform); // May crash if call failed
```

### 7. Check Platform Support
```js
// ✅ Good - check platform before using platform-specific features
const info = await bridge.call({ data: { action: 'deviceInfo' } });
if (info.platform === 'Android') {
  // Only use systemBars on Android
  await bridge.call({
    data: { action: 'systemBars', content: { showStatusBar: false } }
  });
}

// ❌ Bad - using iOS-unsupported feature without check
await bridge.call({
  data: { action: 'systemBars', content: { showStatusBar: false } }
}); // Will fail on iOS
```

### 8. Enable Debug Logging During Development
```js
// ✅ Good - enable debug in development
if (process.env.NODE_ENV === 'development') {
  window.bridge.setDebug(true);
}

// Or based on URL parameter
const urlParams = new URLSearchParams(window.location.search);
if (urlParams.get('debug') === 'true') {
  window.bridge.setDebug(true);
}
```

---

## Complete Example

Here's a complete example showing best practices:

```js
// Initialize the bridge
async function initBridge() {
  try {
    // 1. Wait for bridge to be ready
    await window.bridge.ready();
    console.log('Bridge ready, schema version:', window.bridge.schemaVersion);
    
    // 2. Enable debug in development
    if (process.env.NODE_ENV === 'development') {
      window.bridge.setDebug(true);
    }
    
    // 3. Set up event listener (once!)
    window.bridge.on(handleNativeMessage);
    
    // 4. Get device info with timeout
    const deviceInfo = await window.bridge.call(
      { data: { action: 'deviceInfo' } },
      { timeout: 5000 }
    );
    console.log('Running on:', deviceInfo.platform, deviceInfo.model);
    
    // 5. Enable lifecycle events
    await window.bridge.call({
      data: { action: 'lifecycleEvents', content: { enable: true } }
    });
    
    // 6. Track screen view (fire-and-forget)
    window.bridge.call({
      data: {
        action: 'trackScreen',
        content: { screenName: 'Home', screenClass: 'HomeScreen' }
      }
    });
    
    return deviceInfo;
  } catch (error) {
    console.error('Bridge initialization error:', error.message);
    // Provide fallback behavior
    return { platform: 'unknown', model: 'unknown' };
  }
}

// Handle messages from native
function handleNativeMessage(message) {
  const { action, content } = message.data || {};
  
  switch (action) {
    case 'lifecycle':
      if (content?.event === 'focused') {
        console.log('App resumed - refreshing data');
        refreshData();
      }
      break;
      
    case 'onPushNotification':
      console.log('Push notification:', content);
      if (content?.url) {
        // Navigate to the URL from the push
        window.location.href = content.url;
      }
      break;
      
    default:
      console.log('Unhandled native event:', action);
  }
  
  return { status: 'received' };
}

// Example: Show a toast with error handling
async function showSuccessMessage(message) {
  try {
    await window.bridge.call({
      data: {
        action: 'showToast',
        content: { message, duration: 'short' }
      }
    }, { timeout: 3000 });
  } catch (error) {
    // Fallback to web alert if bridge fails
    console.error('Toast failed:', error.message);
    alert(message);
  }
}

// Initialize on page load
initBridge().then(deviceInfo => {
  console.log('App ready on', deviceInfo.platform);
});
```

---

## Additional Resources

- **Live Demo:** Check `android-sample/app/src/main/assets/index.html` for a complete interactive demo with all bridge features
- **Native Implementation:** See `JavaScriptBridge.kt` for the Android/iOS bridge implementation details

---

**Questions or issues?** Contact the mobile team or check the bridge demo for working examples of every feature.


