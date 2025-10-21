import Foundation

/// Contains the JavaScript code that will be injected into the WebView
///
/// **Why inject JavaScript?**
/// - **Bridge Establishment**: Creates the communication channel between web and native
/// - **Promise-based API**: Provides modern, async/await-compatible JavaScript interface
/// - **Request-Response Matching**: Handles correlation of responses to their originating requests
/// - **Timeout Management**: Prevents hanging promises when native doesn't respond
///
/// **Design Decision:**
/// Injecting at document start ensures the bridge is available before any page scripts run.
/// This prevents race conditions where web code tries to use the bridge before it's ready.
///
/// **Why an IIFE?**
/// The Immediately Invoked Function Expression (IIFE) pattern:
/// - Prevents polluting the global scope with internal variables
/// - Encapsulates implementation details
/// - Only exposes the public `window.bridge` interface
struct JavaScriptBridgeScript {
    /// Generates the JavaScript bridge code with the specified schema version
    ///
    /// **Why parameterize the version?** Allows the native side to communicate its capabilities
    /// to JavaScript, enabling feature detection and graceful degradation.
    ///
    /// **Message Structure:** The bridge sends messages to native with this format:
    /// ```
    /// {
    ///   version: <schemaVersion>,
    ///   id: <unique-id>,
    ///   data: { action: <string>, content: <optional-object> }
    /// }
    /// ```
    ///
    /// **Debug Mode:** Debug logging is disabled by default and can be enabled from JavaScript
    /// by calling `window.bridge.setDebug(true)`. This allows dynamic control of logging
    /// without requiring app rebuild.
    ///
    /// - Parameters:
    ///   - schemaVersion: The schema version of the bridge protocol
    ///   - debug: Initial debug logging state (defaults to false)
    static func source(schemaVersion: Int, debug: Bool = false) -> String {
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
                    const SCHEMA_VERSION = \(schemaVersion);
                    const DEFAULT_TIMEOUT = 30000; // 30 seconds
                    let debug = \(debug ? "true" : "false");
                    
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
                        return `msg_${Date.now()}_${++messageIdCounter}_${Math.random().toString(36).substr(2, 9)}`;
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
                        if (!window.webkit?.messageHandlers?.bridge) {
                            throw new Error('Native bridge not available');
                        }
                        
                        try {
                            const messageString = JSON.stringify(message);
                            window.webkit.messageHandlers.bridge.postMessage(messageString);
                        } catch (error) {
                            throw new Error(`Failed to send message: ${error.message}`);
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
                            debugLog(`Debug logging ${debug ? 'enabled' : 'disabled'}`);
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
                                        debugLog(`Request timeout for id: ${id}`);
                                        reject(new Error(`Request timeout after ${timeout}ms`));
                                    }, timeout);
                                    
                                    // Store promise handlers
                                    pendingPromises.set(id, {
                                        resolve: (data) => {
                                            cleanupPromise(id, timeoutId);
                                            debugLog(`Request resolved for id: ${id}`, data);
                                            resolve(data);
                                        },
                                        reject: (error) => {
                                            cleanupPromise(id, timeoutId);
                                            debugLog(`Request rejected for id: ${id}`, error);
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
                        }
                    };
                    
                    /**
                     * Handle response from native
                     * @internal
                     */
                    window.__bridgeHandleResponse = function(response) {
                        debugLog('Received response:', response);
                        
                        if (!response || typeof response !== 'object' || !response.id) {
                            console.error('[Bridge] Invalid response format:', response);
                            return;
                        }
                        
                        const promise = pendingPromises.get(response.id);
                        if (!promise) {
                            debugLog(`No pending promise found for id: ${response.id}`);
                            return;
                        }
                        
                        if (response.success) {
                            promise.resolve(response.data ?? {});
                        } else {
                            const error = new Error(response.error?.message ?? 'Unknown error');
                            if (response.error?.code) {
                                error.code = response.error.code;
                            }
                            promise.reject(error);
                        }
                    };
                    
                    /**
                     * Handle message from native
                     * @internal
                     */
                    window.__bridgeReceiveNativeMessage = function(message) {
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
                        console.log(`[Bridge] ✓ iOS JavaScript Bridge initialized successfully (schema version ${SCHEMA_VERSION}) - took ${initDuration.toFixed(2)}ms`);
                        debugLog(`iOS JavaScript Bridge ready (schema version ${SCHEMA_VERSION})`);
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

