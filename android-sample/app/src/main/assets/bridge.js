/**
 * JavaScript Bridge Implementation
 * Implements the JavaScript Bridge Specification for Android
 * 
 * This bridge provides bidirectional communication between WebView and Android native code.
 */
(function() {
  'use strict';
  
  const pendingCalls = new Map();
  let messageHandler = null;
  let messageQueue = [];
  let bridgeReady = false;
  let debugEnabled = false;
  
  function log(...args) {
    if (debugEnabled) {
      console.log('[Bridge]', ...args);
    }
  }
  
  window.bridge = {
    isReady: false,
    version: '1.0.0',
    
    /**
     * Wait for bridge to be ready
     * @returns {Promise<void>}
     */
    async ready() {
      if (bridgeReady) return;
      return new Promise((resolve) => {
        window.addEventListener('bridgeReady', () => resolve(), { once: true });
      });
    },
    
    /**
     * Call native code
     * @param {Object} message - Message object with data.action and data.content
     * @param {Object} options - Optional timeout and signal
     * @returns {Promise<any>} - Response from native
     */
    async call(message, options = {}) {
      const { timeout = 30000, signal } = options;
      const id = Math.random().toString(36).substr(2, 9);
      
      // Add id to message for request-response pattern
      const messageWithId = { ...message, id };
      
      log('Calling native:', messageWithId);
      
      return new Promise((resolve, reject) => {
        // Setup timeout
        const timeoutId = setTimeout(() => {
          pendingCalls.delete(id);
          const error = new Error('Request timeout');
          error.code = 'TIMEOUT';
          reject(error);
        }, timeout);
        
        // Setup abort signal
        if (signal) {
          signal.addEventListener('abort', () => {
            clearTimeout(timeoutId);
            pendingCalls.delete(id);
            const error = new Error('Request aborted');
            error.name = 'AbortError';
            reject(error);
          }, { once: true });
        }
        
        // Store pending call
        pendingCalls.set(id, { resolve, reject, timeoutId });
        
        // Send to native
        try {
          if (window.AndroidBridge) {
            // Android
            window.AndroidBridge.postMessage(JSON.stringify(messageWithId));
          } else if (window.webkit?.messageHandlers?.bridge) {
            // iOS (for future compatibility)
            window.webkit.messageHandlers.bridge.postMessage(messageWithId);
          } else {
            clearTimeout(timeoutId);
            pendingCalls.delete(id);
            const error = new Error('Bridge not available');
            error.code = 'BRIDGE_NOT_AVAILABLE';
            reject(error);
          }
        } catch (e) {
          clearTimeout(timeoutId);
          pendingCalls.delete(id);
          reject(e);
        }
      });
    },
    
    /**
     * Register a handler for incoming messages from native
     * @param {Function} handler - Async function to handle messages
     */
    on(handler) {
      log('Registering message handler');
      messageHandler = handler;
    },
    
    /**
     * Remove the message handler
     */
    off() {
      log('Removing message handler');
      messageHandler = null;
    },
    
    /**
     * Enable or disable debug logging
     * @param {boolean} enabled
     */
    setDebug(enabled) {
      debugEnabled = enabled;
      console.log(`Bridge debug mode: ${enabled}`);
    },
    
    /**
     * Internal: Handle responses from native
     * This is called by native code when it sends a response
     */
    _onNativeResponse(response) {
      log('Received response from native:', response);
      
      const { id, result, error } = response;
      const pending = pendingCalls.get(id);
      
      if (pending) {
        clearTimeout(pending.timeoutId);
        pendingCalls.delete(id);
        
        if (error) {
          const err = new Error(error.message || 'Native error');
          err.code = error.code || 'NATIVE_ERROR';
          err.details = error;
          pending.reject(err);
        } else {
          pending.resolve(result);
        }
      } else {
        console.warn('Received response for unknown request:', id);
      }
    },
    
    /**
     * Internal: Handle messages from native
     * This is called by native code when it sends a message to web
     */
    async _onNativeMessage(message) {
      log('Received message from native:', message);
      
      if (!messageHandler) {
        console.warn('No message handler registered, ignoring message');
        return;
      }
      
      try {
        const result = await messageHandler(message);
        
        // If message has id, send response back
        if (message.id && result !== undefined) {
          const response = { id: message.id, result };
          log('Sending response back to native:', response);
          
          if (window.AndroidBridge) {
            window.AndroidBridge.postMessage(JSON.stringify(response));
          } else if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          }
        }
      } catch (error) {
        console.error('Error handling native message:', error);
        
        // Send error back if message expects response
        if (message.id) {
          const response = {
            id: message.id,
            error: { 
              code: 'JS_ERROR', 
              message: error.message || String(error) 
            }
          };
          
          if (window.AndroidBridge) {
            window.AndroidBridge.postMessage(JSON.stringify(response));
          } else if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          }
        }
      }
    }
  };
  
  // Mark as ready
  bridgeReady = true;
  window.bridge.isReady = true;
  window.dispatchEvent(new Event('bridgeReady'));
  
  log('Bridge initialized and ready');
  
  // Flush queued messages
  messageQueue.forEach(msg => window.bridge.call(msg));
  messageQueue = [];
})();

