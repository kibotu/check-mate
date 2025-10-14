package com.check24.bridgesample

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.widget.Toast
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Bridge interface between WebView JavaScript and Android native code.
 * Implements the JavaScript Bridge Specification.
 * 
 * IMPORTANT: Methods annotated with @JavascriptInterface run on a background thread.
 * All WebView operations MUST be posted to the main thread.
 */
class BridgeInterface(private val webView: WebView) {
    
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingRequests = ConcurrentHashMap<String, PendingRequest>()
    private var debugEnabled = false
    
    companion object {
        private const val TAG = "BridgeInterface"
    }
    
    /**
     * Internal data class to track pending requests with timeout handling
     */
    private data class PendingRequest(
        val continuation: Continuation<JSONObject>,
        val timeoutRunnable: Runnable
    )
    
    /**
     * Main entry point for messages from JavaScript.
     * This method is called from JavaScript using window.AndroidBridge.postMessage()
     * 
     * Handles two types of messages:
     * 1. Regular messages with action: {data: {action, content}, id?}
     * 2. Responses to native's callWeb: {id, result/error}
     * 
     * @param jsonString JSON string containing the message from web
     */
    @JavascriptInterface
    fun postMessage(jsonString: String) {
        try {
            if (debugEnabled) {
                Log.d(TAG, "Received from web: $jsonString")
            }
            
            val message = JSONObject(jsonString)
            
            // Check if this is a response to native's callWeb request
            // Responses have 'id' and 'result' or 'error', but no 'data'
            if (message.has("id") && !message.has("data")) {
                // This is a response to our callWeb request
                handleWebResponse(jsonString)
                return
            }
            
            // Regular message with action
            val data = message.getJSONObject("data")
            val action = data.getString("action")
            val content = data.optJSONObject("content")
            val id = if (message.has("id")) message.getString("id") else null
            
            // Handle on main thread
            mainHandler.post {
                handleAction(action, content, id)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message from web", e)
            // Try to send error back if we can parse the ID
            try {
                val message = JSONObject(jsonString)
                if (message.has("id") && message.has("data")) {
                    val id = message.getString("id")
                    // Must post to main thread for evaluateJavascript
                    mainHandler.post {
                        sendError(id, "PARSE_ERROR", "Failed to parse message: ${e.message}")
                    }
                }
            } catch (parseError: Exception) {
                Log.e(TAG, "Could not send error response", parseError)
            }
        }
    }
    
    /**
     * Handle incoming actions from web
     */
    private fun handleAction(action: String, content: JSONObject?, id: String?) {
        if (debugEnabled) {
            Log.d(TAG, "Handling action: $action, hasId: ${id != null}")
        }
        
        try {
            when (action) {
                "getDeviceInfo" -> {
                    val result = JSONObject().apply {
                        put("platform", "Android")
                        put("osVersion", Build.VERSION.RELEASE)
                        put("sdkInt", Build.VERSION.SDK_INT)
                        put("manufacturer", Build.MANUFACTURER)
                        put("model", Build.MODEL)
                        put("device", Build.DEVICE)
                    }
                    if (id != null) {
                        sendResult(id, result)
                    }
                }
                
                "showToast" -> {
                    val message = content?.optString("message") ?: "Hello from native!"
                    val duration = when (content?.optString("duration")) {
                        "long" -> Toast.LENGTH_LONG
                        else -> Toast.LENGTH_SHORT
                    }
                    Toast.makeText(webView.context, message, duration).show()
                    
                    if (id != null) {
                        sendResult(id, JSONObject().apply {
                            put("success", true)
                        })
                    }
                }
                
                "trackEvent" -> {
                    // Fire-and-forget analytics event
                    val eventName = content?.optString("event") ?: "unknown"
                    val properties = content?.optJSONObject("properties")
                    Log.i(TAG, "Track event: $eventName, properties: $properties")
                    
                    // In a real app, send to analytics service here
                    // No response needed for fire-and-forget
                }
                
                "requestPermission" -> {
                    val permission = content?.optString("permission") ?: "unknown"
                    Log.i(TAG, "Permission requested: $permission")
                    
                    // In a real app, check and request actual permissions
                    // For demo, we'll just return granted
                    if (id != null) {
                        sendResult(id, JSONObject().apply {
                            put("granted", true)
                            put("permission", permission)
                        })
                    }
                }
                
                "navigate" -> {
                    val url = content?.optString("url")
                    Log.i(TAG, "Navigate to: $url")
                    
                    // In a real app, handle navigation
                    if (id != null) {
                        sendResult(id, JSONObject().apply {
                            put("success", true)
                            put("url", url)
                        })
                    }
                }
                
                "getSecureData" -> {
                    val key = content?.optString("key") ?: ""
                    Log.i(TAG, "Get secure data: $key")
                    
                    // In a real app, retrieve from secure storage (KeyStore, etc.)
                    // For demo, return mock data
                    if (id != null) {
                        sendResult(id, JSONObject().apply {
                            put("value", "mock_secure_value_for_$key")
                            put("found", true)
                        })
                    }
                }
                
                "setSecureData" -> {
                    val key = content?.optString("key") ?: ""
                    val value = content?.optString("value") ?: ""
                    Log.i(TAG, "Set secure data: $key = $value")
                    
                    // In a real app, store in secure storage
                    if (id != null) {
                        sendResult(id, JSONObject().apply {
                            put("success", true)
                        })
                    }
                }
                
                else -> {
                    // Unknown action
                    if (id != null) {
                        sendError(id, "UNKNOWN_ACTION", "Action '$action' is not supported")
                    } else {
                        Log.w(TAG, "Unknown action (fire-and-forget): $action")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling action: $action", e)
            if (id != null) {
                sendError(id, "NATIVE_ERROR", "Error handling action: ${e.message}")
            }
        }
    }
    
    /**
     * Send successful result back to web
     * MUST be called from main thread
     */
    private fun sendResult(id: String, result: JSONObject) {
        try {
            val response = JSONObject().apply {
                put("id", id)
                put("result", result)
            }
            
            if (debugEnabled) {
                Log.d(TAG, "Sending result: $response")
            }
            
            val js = "window.bridge._onNativeResponse($response)"
            webView.evaluateJavascript(js, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending result", e)
        }
    }
    
    /**
     * Send error back to web
     * MUST be called from main thread
     */
    private fun sendError(id: String, code: String, message: String) {
        try {
            val response = JSONObject().apply {
                put("id", id)
                put("error", JSONObject().apply {
                    put("code", code)
                    put("message", message)
                })
            }
            
            if (debugEnabled) {
                Log.d(TAG, "Sending error: $response")
            }
            
            val js = "window.bridge._onNativeResponse($response)"
            webView.evaluateJavascript(js, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending error response", e)
        }
    }
    
    /**
     * Send event to web (fire-and-forget)
     * Can be called from any thread
     */
    fun sendEventToWeb(action: String, content: Map<String, Any>) {
        mainHandler.post {
            try {
                val message = JSONObject().apply {
                    put("data", JSONObject().apply {
                        put("action", action)
                        put("content", JSONObject(content))
                    })
                }
                
                if (debugEnabled) {
                    Log.d(TAG, "Sending event to web: $message")
                }
                
                val js = "window.bridge._onNativeMessage($message)"
                webView.evaluateJavascript(js, null)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending event to web", e)
            }
        }
    }
    
    /**
     * Call web and await response (request-response pattern)
     * Uses Kotlin coroutines for async operation
     */
    suspend fun callWeb(action: String, content: Map<String, Any>): JSONObject = 
        suspendCancellableCoroutine { continuation ->
            val id = UUID.randomUUID().toString()
            
            // Create timeout runnable
            val timeoutRunnable = Runnable {
                val pending = pendingRequests.remove(id)
                if (pending != null) {
                    pending.continuation.resumeWithException(
                        Exception("Timeout waiting for web response")
                    )
                }
            }
            
            // Store pending request with timeout
            pendingRequests[id] = PendingRequest(continuation, timeoutRunnable)
            
            // Clean up on cancellation
            continuation.invokeOnCancellation {
                val pending = pendingRequests.remove(id)
                if (pending != null) {
                    mainHandler.removeCallbacks(pending.timeoutRunnable)
                }
            }
            
            mainHandler.post {
                try {
                    val message = JSONObject().apply {
                        put("data", JSONObject().apply {
                            put("action", action)
                            put("content", JSONObject(content))
                        })
                        put("id", id)
                    }
                    
                    if (debugEnabled) {
                        Log.d(TAG, "Calling web: $message")
                    }
                    
                    // Setup timeout (30 seconds)
                    mainHandler.postDelayed(timeoutRunnable, 30000)
                    
                    val js = "window.bridge._onNativeMessage($message)"
                    webView.evaluateJavascript(js, null)
                    
                } catch (e: Exception) {
                    val pending = pendingRequests.remove(id)
                    if (pending != null) {
                        mainHandler.removeCallbacks(pending.timeoutRunnable)
                        pending.continuation.resumeWithException(e)
                    }
                }
            }
        }
    
    /**
     * Handle response from web (called internally by the web bridge)
     * This is called when web responds to a native callWeb request
     */
    private fun handleWebResponse(responseJson: String) {
        try {
            val response = JSONObject(responseJson)
            val id = response.getString("id")
            val pending = pendingRequests.remove(id)
            
            if (pending != null) {
                // Cancel the timeout
                mainHandler.removeCallbacks(pending.timeoutRunnable)
                
                // Resume the continuation with result or error
                if (response.has("error")) {
                    val error = response.getJSONObject("error")
                    pending.continuation.resumeWithException(
                        Exception(error.optString("message", "Unknown error"))
                    )
                } else {
                    val result = response.optJSONObject("result") ?: JSONObject()
                    pending.continuation.resume(result)
                }
            } else {
                Log.w(TAG, "Received response for unknown request ID: $id")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling web response", e)
        }
    }
    
    /**
     * Enable/disable debug logging
     */
    fun setDebug(enabled: Boolean) {
        debugEnabled = enabled
        Log.i(TAG, "Debug mode: $enabled")
    }
}

