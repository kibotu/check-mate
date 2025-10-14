//
//  WebViewBridge.swift
//  BridgeSample
//
//  Complete bridge implementation including JavaScript injection
//

import Foundation
import WebKit

/// JavaScript bridge code to be injected into the WebView
/// This implements the complete bridge specification
struct BridgeJavaScript {
    static let source = """
(function() {
  'use strict';
  
  const pendingCalls = new Map();
  let messageHandler = null;
  let messageQueue = [];
  let bridgeReady = false;
  let debugMode = false;
  
  function log(...args) {
    if (debugMode) {
      console.log('[Bridge]', ...args);
    }
  }
  
  window.bridge = {
    isReady: false,
    version: '1.0.0',
    
    async ready() {
      if (bridgeReady) return;
      log('Waiting for bridge to be ready...');
      return new Promise((resolve) => {
        window.addEventListener('bridgeReady', () => {
          log('Bridge ready event received');
          resolve();
        }, { once: true });
      });
    },
    
    async call(message, options = {}) {
      const { timeout = 30000, signal } = options;
      const id = Math.random().toString(36).substr(2, 9);
      
      log('Calling native:', message.data?.action, 'with id:', id);
      
      // Add id to message for request-response pattern
      const messageWithId = { ...message, id };
      
      return new Promise((resolve, reject) => {
        // Setup timeout
        const timeoutId = setTimeout(() => {
          pendingCalls.delete(id);
          const error = new Error('Operation timed out');
          error.code = 'TIMEOUT';
          log('Call timed out:', id);
          reject(error);
        }, timeout);
        
        // Setup abort signal
        if (signal) {
          signal.addEventListener('abort', () => {
            clearTimeout(timeoutId);
            pendingCalls.delete(id);
            const error = new Error('Operation aborted');
            error.name = 'AbortError';
            log('Call aborted:', id);
            reject(error);
          }, { once: true });
        }
        
        // Store pending call
        pendingCalls.set(id, { resolve, reject, timeoutId });
        
        // Send to native
        try {
          if (window.webkit?.messageHandlers?.bridge) {
            // iOS
            log('Sending to iOS bridge');
            window.webkit.messageHandlers.bridge.postMessage(messageWithId);
          } else {
            clearTimeout(timeoutId);
            pendingCalls.delete(id);
            const error = new Error('Bridge not available');
            error.code = 'BRIDGE_UNAVAILABLE';
            reject(error);
          }
        } catch (err) {
          clearTimeout(timeoutId);
          pendingCalls.delete(id);
          log('Error sending message:', err);
          reject(err);
        }
      });
    },
    
    on(handler) {
      log('Registering message handler');
      messageHandler = handler;
    },
    
    off() {
      log('Removing message handler');
      messageHandler = null;
    },
    
    setDebug(enabled) {
      debugMode = enabled;
      console.log(`[Bridge] Debug mode: ${enabled}`);
    },
    
    // Internal: Handle responses from native
    _onNativeResponse(response) {
      log('Received native response:', response);
      const { id, result, error } = response;
      const pending = pendingCalls.get(id);
      
      if (pending) {
        clearTimeout(pending.timeoutId);
        pendingCalls.delete(id);
        
        if (error) {
          const err = new Error(error.message || 'Unknown error');
          err.code = error.code || 'UNKNOWN';
          err.details = error.details;
          log('Native returned error:', err);
          pending.reject(err);
        } else {
          log('Native returned result:', result);
          pending.resolve(result);
        }
      } else {
        log('Warning: No pending call found for id:', id);
      }
    },
    
    // Internal: Handle messages from native
    async _onNativeMessage(message) {
      log('Received native message:', message);
      
      if (!messageHandler) {
        console.warn('[Bridge] No message handler registered');
        
        // If message has id, send error back
        if (message.id) {
          const response = {
            version: '1.0',
            id: message.id,
            error: { code: 'NO_HANDLER', message: 'No message handler registered' }
          };
          
          if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          }
        }
        return;
      }
      
      try {
        const result = await messageHandler(message);
        
        // If message has id, send response back
        if (message.id) {
          const response = { version: '1.0', id: message.id, result: result !== undefined ? result : null };
          log('Sending response to native:', response);
          
          if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          }
        }
      } catch (error) {
        log('Error in message handler:', error);
        
        // Send error back if message expects response
        if (message.id) {
          const response = {
            version: '1.0',
            id: message.id,
            error: { code: 'JS_ERROR', message: error.message || String(error) }
          };
          
          if (window.webkit?.messageHandlers?.bridge) {
            window.webkit.messageHandlers.bridge.postMessage(response);
          }
        }
      }
    }
  };
  
  // Mark as ready
  bridgeReady = true;
  window.bridge.isReady = true;
  log('Bridge initialized');
  window.dispatchEvent(new Event('bridgeReady'));
  
  // Flush queued messages (if any were added before ready)
  messageQueue.forEach(msg => window.bridge.call(msg));
  messageQueue = [];
})();
"""
}

/// Bridge error types
enum BridgeError: LocalizedError {
    case invalidMessage
    case jsonSerializationFailed
    case actionNotFound(String)
    case invalidParameters
    case permissionDenied
    case timeout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMessage:
            return "Invalid message format"
        case .jsonSerializationFailed:
            return "Failed to serialize JSON"
        case .actionNotFound(let action):
            return "Action '\(action)' not found"
        case .invalidParameters:
            return "Invalid parameters"
        case .permissionDenied:
            return "Permission denied"
        case .timeout:
            return "Operation timed out"
        case .unknown(let message):
            return message
        }
    }
    
    var code: String {
        switch self {
        case .invalidMessage:
            return "INVALID_MESSAGE"
        case .jsonSerializationFailed:
            return "JSON_ERROR"
        case .actionNotFound:
            return "UNKNOWN_ACTION"
        case .invalidParameters:
            return "INVALID_PARAMS"
        case .permissionDenied:
            return "PERMISSION_DENIED"
        case .timeout:
            return "TIMEOUT"
        case .unknown:
            return "UNKNOWN"
        }
    }
}

/// Type alias for pending request continuations
typealias PendingRequest = CheckedContinuation<Any?, Error>

