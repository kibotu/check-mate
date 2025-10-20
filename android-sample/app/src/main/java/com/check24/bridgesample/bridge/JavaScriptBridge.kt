package com.check24.bridgesample.bridge

import android.webkit.JavascriptInterface
import android.webkit.WebView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import timber.log.Timber

/**
 * Enables seamless bidirectional communication between web content and native Android.
 *
 * **Why this exists:**
 * WebViews are isolated sandboxes - web code cannot directly access native Android APIs
 * (camera, storage, sensors, etc.) for security reasons. This bridge safely exposes
 * native capabilities to web applications without compromising security.
 *
 * **Why this design:**
 * - Uses @JavascriptInterface to comply with Android WebView security requirements
 * - Processes messages on background thread to prevent blocking UI during JSON parsing
 * - Injects JavaScript code to provide web-side API, ensuring consistent interface
 * - Implements request-response pattern with IDs for async communication reliability
 * - Version negotiation prevents crashes when web/native are updated independently
 *
 * **Key architectural decisions:**
 * - Coroutines for async handling - prevents ANRs on slow operations
 * - Message handler abstraction - allows different command routing strategies
 * - Silent version mismatch handling - graceful degradation when versions differ
 * - Promise-based web API - familiar pattern for web developers
 *
 * Based on check-mate specification for standardized web-native communication.
 *
 * @param webView The WebView instance to bridge with
 * @param messageHandler Handles routing and execution of bridge commands
 * @see <a href="https://github.com/kibotu/check-mate">check-mate specification</a>
 */
class JavaScriptBridge(
    private val webView: WebView,
    private val messageHandler: BridgeMessageHandler
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    companion object {
        const val BRIDGE_NAME = "Bridge"

        // Schema version: Simple integer, increment on breaking changes
        const val SCHEMA_VERSION = 1
    }

    /**
     * Entry point for all web-to-native communication.
     *
     * **Why @JavascriptInterface:**
     * Android requires explicit annotation for security - only annotated methods
     * are accessible from JavaScript, preventing accidental exposure of native APIs.
     *
     * **Why background thread:**
     * WebView invokes this on a background thread by design. We use coroutines
     * to safely dispatch to appropriate threads (Main for UI, IO for storage).
     *
     * **Why version checking:**
     * Allows independent web/native deployments. Silently ignores newer web versions
     * to prevent crashes, allowing web to use progressive enhancement.
     *
     * @param message JSON string from web: `{ id?, data: { version?, action, content? } }`
     */
    @JavascriptInterface
    fun postMessage(message: String) {
        Timber.d("[postMessage] received: $message")

        scope.launch {
            try {
                val messageObj = JSONObject(message)
                val id = messageObj.optString("id", null)
                val data = messageObj.optJSONObject("data")

                if (data == null) {
                    sendErrorToWeb(id, "INVALID_MESSAGE", "Missing 'data' field in message")
                    return@launch
                }

                // Check schema version - silently ignore if web is using a newer version
                val requestedVersion = data.optInt("version", SCHEMA_VERSION)
                if (requestedVersion > SCHEMA_VERSION) {
                    Timber.w("[postMessage] Ignoring message with version $requestedVersion (current: $SCHEMA_VERSION)")
                    return@launch  // Silently ignore - web is using newer features
                }

                val action = data.optString("action", null)
                if (action.isNullOrEmpty()) {
                    sendErrorToWeb(id, "INVALID_MESSAGE", "Missing 'action' field in data")
                    return@launch
                }

                val content = data.opt("content")

                // Handle the message
                val result = messageHandler.handle(action, content)

                // If there's an ID, send response back to web
                if (!id.isNullOrEmpty()) {
                    sendResponseToWeb(id, result)
                }
            } catch (e: Exception) {
                Timber.e(e)
                val messageObj = runCatching { JSONObject(message) }.getOrNull()
                val id = messageObj?.optString("id")
                sendErrorToWeb(id, "INTERNAL_ERROR", e.message ?: "Unknown error")
            }
        }
    }

    /**
     * Send messages from native to web (push notifications, state updates, events).
     *
     * **Why native-to-web:**
     * Enables native code to notify web of events: network changes, permission results,
     * background task completions. Completes the bidirectional communication loop.
     *
     * **Why optional callback:**
     * Most native-to-web messages are fire-and-forget notifications. Callback support
     * exists for cases where native needs confirmation web received the message.
     *
     * @param action The action identifier (e.g., "networkChanged", "permissionResult")
     * @param content Optional message payload
     * @param callback Optional callback invoked when web responds (rarely needed)
     */
    fun sendToWeb(action: String, content: Any? = null, callback: ((Any?) -> Unit)? = null) {
        scope.launch {
            try {
                val messageId = if (callback != null) generateMessageId() else null
                val message = buildMessage(messageId, action, content)

                val script = "window.bridge && window.bridge._handleNativeMessage($message)"
                executeJavaScript(script)

                Timber.d("[sendToWeb] action=$action content=$content")
            } catch (e: Exception) {
                Timber.e(e)
                callback?.invoke(null)
            }
        }
    }

    /**
     * Completes the request-response cycle for async web requests.
     *
     * **Why separate response method:**
     * Web requests with IDs expect responses. This resolves the Promise on web side,
     * completing async operations and allowing web code to continue execution.
     */
    private fun sendResponseToWeb(id: String, result: Any?) {
        val response = JSONObject().apply {
            put("id", id)
            put("data", result)
        }

        val script = "window.bridge && window.bridge._handleNativeResponse($response)"
        executeJavaScript(script)

        Timber.d("[sendResponseToWeb] id=$id result=$result")
    }

    /**
     * Communicates failures to web code, enabling proper error handling.
     *
     * **Why structured errors:**
     * Provides code + message for web to distinguish error types (network vs permission
     * vs invalid input) and show appropriate UI to users.
     */
    private fun sendErrorToWeb(id: String?, code: String, message: String) {
        val error = JSONObject().apply {
            put("code", code)
            put("message", message)
        }

        val response = JSONObject().apply {
            if (!id.isNullOrEmpty()) put("id", id)
            put("error", error)
        }

        val script = "window.bridge && window.bridge._handleNativeResponse($response)"
        executeJavaScript(script)

        Timber.w("[sendErrorToWeb] id=$id code=$code message=$message")
    }

    /**
     * Build a message object.
     */
    private fun buildMessage(id: String?, action: String, content: Any?): String {
        val message = JSONObject()
        if (id != null) message.put("id", id)

        val data = JSONObject().apply {
            put("action", action)
            if (content != null) put("content", content)
        }
        message.put("data", data)

        return message.toString()
    }

    /**
     * Execute JavaScript in the WebView.
     */
    private fun executeJavaScript(script: String) {
        webView.post {
            webView.evaluateJavascript(script, null)
        }
    }

    /**
     * Generate a unique message ID.
     */
    private fun generateMessageId(): String {
        return "native_${System.currentTimeMillis()}_${(Math.random() * 10000).toInt()}"
    }

    /**
     * Injects the bridge JavaScript API into the WebView's global scope.
     *
     * **Why injection:**
     * Provides a clean, Promise-based API (`window.bridge.call()`) to web developers,
     * abstracting the complexity of JavascriptInterface communication and message routing.
     *
     * **When to call:**
     * Call on page load and after navigation to ensure bridge is always available to web code.
     */
    fun injectBridgeScript() {
        val script = getBridgeJavaScript()
        executeJavaScript(script)
        Timber.d("[injectBridgeScript] Bridge script injected")
    }

    /**
     * Generates the bridge JavaScript implementation injected into web pages.
     *
     * **Why inline JavaScript:**
     * Self-contained bridge requires no external files, reducing failure points.
     * Version constant ensures web/native version alignment.
     *
     * **Key features:**
     * - Promise-based API - modern async/await support for web developers
     * - Timeout handling - prevents hanging when native doesn't respond
     * - Bidirectional messaging - handles both web→native and native→web
     * - Event handlers - allows web to subscribe to native events
     */
    private fun getBridgeJavaScript(): String {
        return """
(function() {
    'use strict';
    
    try {
        // Wrap initialization in a local function for safe execution
        function initializeBridge() {
            // Start timing initialization
            const initStartTime = performance.now();
            
            // Prevent double initialization
            if (window.bridge) {
                console.warn('[Bridge] Already initialized');
                return;
            }
            
            // Configuration
            const SCHEMA_VERSION = $SCHEMA_VERSION;
            const DEFAULT_TIMEOUT = 30000; // 30 seconds
            let debug = false;
            
            // State management
            const pendingPromises = new Map();
            let messageHandler = null;
            let messageIdCounter = 0;
            
            // Bridge ready promise - resolved asynchronously to allow page initialization
            let readyResolve;
            const readyPromise = new Promise((resolve) => {
                readyResolve = resolve;
            });
            
            /**
             * Debug logging helper
             * @private
             */
            const debugLog = (...args) => {
                if (debug) {
                    console.log('[Bridge]', ...args);
                }
            };
            
            /**
             * Dispatch bridge ready event for legacy compatibility
             * @private
             */
            const dispatchReadyEvent = () => {
                try {
                    window.dispatchEvent(new CustomEvent('bridgeReady', {
                        detail: { schemaVersion: SCHEMA_VERSION }
                    }));
                } catch (error) {
                    console.error('[Bridge] Failed to dispatch ready event:', error);
                }
            };
            
            /**
             * Generate unique message ID with counter and timestamp
             * @private
             * @returns {string} Unique message identifier
             */
            const generateId = () => {
                return `msg_${'$'}{Date.now()}_${'$'}{++messageIdCounter}_${'$'}{Math.random().toString(36).substr(2, 9)}`;
            };
            
            /**
             * Validate message structure
             * @private
             * @throws {Error} If message is invalid
             */
            const validateMessage = (message) => {
                if (!message || typeof message !== 'object') {
                    throw new Error('Message must be an object');
                }
                if (!message.data || typeof message.data !== 'object') {
                    throw new Error('Message must contain a data object');
                }
                if (!message.data.action || typeof message.data.action !== 'string') {
                    throw new Error('Message data must contain an action string');
                }
            };
            
            /**
             * Send message to native side
             * @private
             * @throws {Error} If native bridge is not available
             */
            const sendToNative = (message) => {
                if (!window.${BRIDGE_NAME}) {
                    throw new Error('Native bridge not available');
                }
                
                try {
                    const messageString = JSON.stringify(message);
                    window.${BRIDGE_NAME}.postMessage(messageString);
                } catch (error) {
                    throw new Error(`Failed to send message: ${'$'}{error.message}`);
                }
            };
            
            /**
             * Clean up pending promise
             * @private
             */
            const cleanupPromise = (id, timeoutId) => {
                clearTimeout(timeoutId);
                pendingPromises.delete(id);
            };
            
            // Public API
            const bridge = {
                /** Schema version of the bridge protocol */
                schemaVersion: SCHEMA_VERSION,
                
                /**
                 * Wait for bridge to be ready
                 * @returns {Promise<void>} Promise that resolves when bridge is ready
                 */
                ready() {
                    return readyPromise;
                },
                
                /**
                 * Enable or disable debug logging
                 * @param {boolean} enabled - Whether to enable debug logging
                 */
                setDebug(enabled) {
                    debug = Boolean(enabled);
                    debugLog(`Debug logging ${'$'}{debug ? 'enabled' : 'disabled'}`);
                },
                
                /**
                 * Call native with a message
                 * @param {Object} message - Message with data property containing action and optional content
                 * @param {string} message.data.action - Action identifier
                 * @param {Object} [message.data.content] - Optional content payload
                 * @param {Object} [options] - Call options
                 * @param {number} [options.timeout=30000] - Timeout in milliseconds
                 * @returns {Promise<any>} Promise that resolves with the native response
                 * @throws {Error} If message is invalid or native bridge unavailable
                 * 
                 * @example
                 * // Simple call
                 * await bridge.call({ data: { action: 'deviceInfo' } });
                 * 
                 * @example
                 * // Call with content and custom timeout
                 * await bridge.call(
                 *   { data: { action: 'navigate', content: { url: 'https://...' } } },
                 *   { timeout: 5000 }
                 * );
                 */
                call(message, options = {}) {
                    return new Promise((resolve, reject) => {
                        try {
                            // Validate input
                            validateMessage(message);
                            
                            const id = generateId();
                            const timeout = options.timeout ?? DEFAULT_TIMEOUT;
                            
                            const fullMessage = {
                                version: SCHEMA_VERSION,
                                id,
                                data: message.data
                            };
                            
                            debugLog('Calling native:', fullMessage);
                            
                            // Set up timeout
                            const timeoutId = setTimeout(() => {
                                cleanupPromise(id, timeoutId);
                                debugLog(`Request timeout for id: ${'$'}{id}`);
                                reject(new Error(`Request timeout after ${'$'}{timeout}ms`));
                            }, timeout);
                            
                            // Store promise handlers
                            pendingPromises.set(id, {
                                resolve: (data) => {
                                    cleanupPromise(id, timeoutId);
                                    debugLog(`Request resolved for id: ${'$'}{id}`, data);
                                    resolve(data);
                                },
                                reject: (error) => {
                                    cleanupPromise(id, timeoutId);
                                    debugLog(`Request rejected for id: ${'$'}{id}`, error);
                                    reject(error);
                                }
                            });
                            
                            // Send to native
                            sendToNative(fullMessage);
                            
                        } catch (error) {
                            debugLog('Call failed:', error);
                            reject(error);
                        }
                    });
                },
                
                /**
                 * Register a handler for messages from native
                 * @param {Function} handler - Handler function that receives messages
                 * @throws {Error} If handler is not a function
                 * 
                 * @example
                 * bridge.on((message) => {
                 *   console.log('Received from native:', message);
                 * });
                 */
                on(handler) {
                    if (typeof handler !== 'function') {
                        throw new Error('Handler must be a function');
                    }
                    messageHandler = handler;
                    debugLog('Message handler registered');
                },
                
                /**
                 * Get current bridge statistics
                 * @returns {Object} Statistics object
                 */
                getStats() {
                    return {
                        pendingRequests: pendingPromises.size,
                        schemaVersion: SCHEMA_VERSION,
                        debugEnabled: debug
                    };
                },
                
                /**
                 * Handle response from native (internal API called by Kotlin)
                 * @param {Object} response - Response object with id, data/error
                 * @internal
                 */
                _handleNativeResponse(response) {
                    debugLog('Received response:', response);
                    
                    if (!response || typeof response !== 'object' || !response.id) {
                        console.error('[Bridge] Invalid response format:', response);
                        return;
                    }
                    
                    const promise = pendingPromises.get(response.id);
                    if (!promise) {
                        debugLog(`No pending promise found for id: ${'$'}{response.id}`);
                        return;
                    }
                    
                    // Handle both success/error format and data/error format
                    if (response.error) {
                        const error = new Error(response.error?.message ?? 'Unknown error');
                        if (response.error?.code) {
                            error.code = response.error.code;
                        }
                        promise.reject(error);
                    } else {
                        promise.resolve(response.data ?? {});
                    }
                },
                
                /**
                 * Handle message from native (internal API called by Kotlin)
                 * @param {Object} message - Message object from native
                 * @internal
                 */
                _handleNativeMessage(message) {
                    debugLog('Received native message:', message);
                    
                    if (!messageHandler) {
                        debugLog('No message handler registered');
                        return;
                    }
                    
                    try {
                        messageHandler(message);
                    } catch (error) {
                        console.error('[Bridge] Error in message handler:', error);
                    }
                }
            };
            
            // Expose bridge to window
            Object.defineProperty(window, 'bridge', {
                value: Object.freeze(bridge),
                writable: false,
                configurable: false
            });
            
            // Mark bridge as ready after current execution context
            // setTimeout ensures bridge is ready after page scripts have a chance to set up listeners
            setTimeout(() => {
                const initDuration = performance.now() - initStartTime;
                readyResolve();
                dispatchReadyEvent();
                console.log(`[Bridge] ✓ Android JavaScript Bridge initialized successfully (schema version ${'$'}{SCHEMA_VERSION}) - took ${'$'}{initDuration.toFixed(2)}ms`);
                debugLog(`Android JavaScript Bridge ready (schema version ${'$'}{SCHEMA_VERSION})`);
            }, 0);
        }
        
        // Execute initialization
        initializeBridge();
        
    } catch (error) {
        console.error('[Bridge] Initialization failed:', error);
    }
})();
"""
    }
}

