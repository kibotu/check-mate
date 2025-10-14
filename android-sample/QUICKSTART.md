# Quick Start Guide

Get the Android Bridge Sample running in 3 minutes!

## Prerequisites

- ✅ Android Studio (latest version)
- ✅ Android device or emulator (Android 7.0+)

## Steps

### 1. Open Project

```bash
# Open Android Studio
# Select: File > Open
# Navigate to: android-sample/
# Click: OK
```

Wait for Gradle sync to complete (first time may take a few minutes).

### 2. Run the App

- Click the green **Run** button (▶️) in the toolbar
- Or press **Shift + F10** (Windows/Linux) or **Control + R** (Mac)
- Select your device/emulator
- Wait for the app to install and launch

### 3. Test the Bridge

The app will load with a beautiful purple gradient interface showing various test buttons:

**Try these:**
1. **Get Device Info** - See your device details (request-response pattern)
2. **Show Toast** - Display native Android toast messages (fire-and-forget)
3. **Track Event** - Log analytics events (fire-and-forget)
4. **Save/Load Data** - Test secure storage (request-response)
5. **Request Permission** - Test permission flow (request-response)

**Watch the Event Log** at the bottom - it shows all bridge activity including native-to-web events!

## What You'll See

### The Bridge in Action

```
Bridge Status: ✅ Ready
Version: 1.0.0
Platform: Android 13 (Google Pixel 6)

Event Log:
[12:34:56] Bridge initialized
[12:34:56] Platform: Android 13
[12:35:01] Native says: Hello from Android!
[12:35:05] Requesting device info...
[12:35:05] Device info received
```

### Expected Behavior

- ✅ All buttons should respond immediately
- ✅ Toasts appear at the bottom of the screen
- ✅ Event log updates in real-time
- ✅ Device info displays in expandable sections
- ✅ After 5 seconds, you'll see a "Hello from Android!" event

## Troubleshooting

### App won't build?
- Make sure you have Android SDK 24+ installed
- Check Gradle sync completed successfully
- Try: Build > Clean Project, then Build > Rebuild Project

### WebView shows blank screen?
- Check Logcat for errors (View > Tool Windows > Logcat)
- Filter by "BridgeInterface" or "WebView Console"
- Make sure `assets/` files are present

### Bridge not working?
- Open Logcat and filter by "Bridge"
- Look for "Bridge initialized and ready"
- Check for JavaScript errors in "WebView Console" logs

## Next Steps

### Explore the Code

1. **Start with**: `app/src/main/assets/index.html`
   - See how the web side works
   - Try adding a new button

2. **Then check**: `BridgeInterface.kt`
   - See how actions are handled
   - Add your own action

3. **Finally**: `bridge.js`
   - Understand the bridge mechanics
   - See how promises work

### Add Your Own Action

**Step 1: Add handler in `BridgeInterface.kt`:**

```kotlin
"myAction" -> {
    val param = content?.optString("param") ?: ""
    Log.i(TAG, "My action: $param")
    if (id != null) {
        sendResult(id, JSONObject().apply {
            put("message", "Hello from my action!")
        })
    }
}
```

**Step 2: Call from HTML:**

```javascript
async function testMyAction() {
    const result = await window.bridge.call({
        data: {
            action: 'myAction',
            content: { param: 'test' }
        }
    });
    console.log(result);
}
```

**Step 3: Add a button in `index.html`:**

```html
<button onclick="testMyAction()">Test My Action</button>
```

### Debug Tips

Enable verbose logging:
```kotlin
// In MainActivity.onCreate()
bridge.setDebug(true)
```

```javascript
// In JavaScript
window.bridge.setDebug(true);
```

Check Logcat filters:
- `tag:BridgeInterface` - Native bridge logs
- `tag:MainActivity` - Activity logs
- `WebView Console` - JavaScript console logs

## Learn More

📖 Read the full README: [README.md](README.md)  
📋 Check the spec: [../spec.md](../spec.md)  
💻 View the code: `app/src/main/java/com/check24/bridgesample/`

## Need Help?

1. Check Logcat for error messages
2. Ensure JavaScript is enabled (it is by default)
3. Verify bridge is injected before WebView loads
4. Check that assets are in the correct directory

---

**🎉 That's it!** You now have a working JavaScript bridge. Start customizing! 🚀

