package com.check24.bridgesample

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.widget.Toast
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Bridge interface between WebView JavaScript and Android native code.
 * Implements the JavaScript Bridge Specification using Kotlin Serialization.
 * 
 * IMPORTANT: Methods annotated with @JavascriptInterface run on a background thread.
 * All WebView operations MUST be posted to the main thread.
 */
class BridgeInterface(private val webView: WebView) {
    
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingRequests = ConcurrentHashMap<String, PendingRequest>()
    private var debugEnabled = false
    
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }
    
    companion object {
        private const val TAG = "BridgeInterface"
    }
    
    /**
     * Internal data class to track pending requests with timeout handling
     */
    private data class PendingRequest(
        val continuation: Continuation<JsonElement>,
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
            
            // Parse to JsonElement first to determine message type
            val jsonElement = json.parseToJsonElement(jsonString)
            
            if (jsonElement !is JsonObject) {
                Log.e(TAG, "Message is not a JSON object")
                return
            }
            
            // Check if this is a response to native's callWeb request
            // Responses have 'id' and 'result' or 'error', but no 'data'
            if (jsonElement.containsKey("id") && !jsonElement.containsKey("data")) {
                // This is a response to our callWeb request
                val response = json.decodeFromString<BridgeResponse>(jsonString)
                handleWebResponse(response)
                return
            }
            
            // Regular message with action
            val message = json.decodeFromString<BridgeMessage>(jsonString)
            val action = message.data.action
            val content = message.data.content
            val id = message.id
            
            // Handle on main thread
            mainHandler.post {
                handleAction(action, content, id)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message from web", e)
            // Try to send error back if we can parse the ID
            try {
                val jsonElement = json.parseToJsonElement(jsonString)
                if (jsonElement is JsonObject && jsonElement.containsKey("id") && jsonElement.containsKey("data")) {
                    val id = jsonElement["id"]?.toString()?.removeSurrounding("\"")
                    if (id != null) {
                        // Must post to main thread for evaluateJavascript
                        mainHandler.post {
                            sendError(id, "PARSE_ERROR", "Failed to parse message: ${e.message}")
                        }
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
    private fun handleAction(action: String, content: JsonElement?, id: String?) {
        if (debugEnabled) {
            Log.d(TAG, "Handling action: $action, hasId: ${id != null}")
        }
        
        try {
            when (action) {
                "getDeviceInfo" -> {
                    val result = buildJsonObject {
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
                    val contentObj = content as? JsonObject
                    val message = contentObj?.get("message")?.toString()?.removeSurrounding("\"") ?: "Hello from native!"
                    val durationStr = contentObj?.get("duration")?.toString()?.removeSurrounding("\"")
                    val duration = when (durationStr) {
                        "long" -> Toast.LENGTH_LONG
                        else -> Toast.LENGTH_SHORT
                    }
                    Toast.makeText(webView.context, message, duration).show()
                    
                    if (id != null) {
                        sendResult(id, buildJsonObject {
                            put("success", true)
                        })
                    }
                }
                
                "trackEvent" -> {
                    // Fire-and-forget analytics event
                    val contentObj = content as? JsonObject
                    val eventName = contentObj?.get("event")?.toString()?.removeSurrounding("\"") ?: "unknown"
                    val properties = contentObj?.get("properties")
                    Log.i(TAG, "Track event: $eventName, properties: $properties")
                    
                    // In a real app, send to analytics service here
                    // No response needed for fire-and-forget
                }
                
                "requestPermission" -> {
                    val contentObj = content as? JsonObject
                    val permission = contentObj?.get("permission")?.toString()?.removeSurrounding("\"") ?: "unknown"
                    Log.i(TAG, "Permission requested: $permission")
                    
                    // In a real app, check and request actual permissions
                    // For demo, we'll just return granted
                    if (id != null) {
                        sendResult(id, buildJsonObject {
                            put("granted", true)
                            put("permission", permission)
                        })
                    }
                }
                
                "navigate" -> {
                    val contentObj = content as? JsonObject
                    val url = contentObj?.get("url")?.toString()?.removeSurrounding("\"")
                    Log.i(TAG, "Navigate to: $url")
                    
                    // In a real app, handle navigation
                    if (id != null) {
                        sendResult(id, buildJsonObject {
                            put("success", true)
                            put("url", url ?: "")
                        })
                    }
                }
                
                "getSecureData" -> {
                    val contentObj = content as? JsonObject
                    val key = contentObj?.get("key")?.toString()?.removeSurrounding("\"") ?: ""
                    Log.i(TAG, "Get secure data: $key")
                    
                    // In a real app, retrieve from secure storage (KeyStore, etc.)
                    // For demo, return mock data
                    if (id != null) {
                        sendResult(id, buildJsonObject {
                            put("value", "mock_secure_value_for_$key")
                            put("found", true)
                        })
                    }
                }
                
                "setSecureData" -> {
                    val contentObj = content as? JsonObject
                    val key = contentObj?.get("key")?.toString()?.removeSurrounding("\"") ?: ""
                    val value = contentObj?.get("value")?.toString()?.removeSurrounding("\"") ?: ""
                    Log.i(TAG, "Set secure data: $key = $value")
                    
                    // In a real app, store in secure storage
                    if (id != null) {
                        sendResult(id, buildJsonObject {
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
    private fun sendResult(id: String, result: JsonElement) {
        try {
            val response = BridgeResponse(
                id = id,
                result = result
            )
            
            val responseJson = json.encodeToString(response)
            
            if (debugEnabled) {
                Log.d(TAG, "Sending result: $responseJson")
            }
            
            val js = "window.bridge._onNativeResponse($responseJson)"
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
            val response = BridgeResponse(
                id = id,
                error = BridgeError(code = code, message = message)
            )
            
            val responseJson = json.encodeToString(response)
            
            if (debugEnabled) {
                Log.d(TAG, "Sending error: $responseJson")
            }
            
            val js = "window.bridge._onNativeResponse($responseJson)"
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
                val contentJson = buildJsonObject {
                    content.forEach { (key, value) ->
                        when (value) {
                            is String -> put(key, value)
                            is Number -> put(key, JsonPrimitive(value))
                            is Boolean -> put(key, value)
                            else -> put(key, value.toString())
                        }
                    }
                }
                
                val message = EventMessage(
                    data = MessageData(
                        action = action,
                        content = contentJson
                    )
                )
                
                val messageJson = json.encodeToString(message)
                
                if (debugEnabled) {
                    Log.d(TAG, "Sending event to web: $messageJson")
                }
                
                val js = "window.bridge._onNativeMessage($messageJson)"
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
    suspend fun callWeb(action: String, content: Map<String, Any>): JsonElement = 
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
                    val contentJson = buildJsonObject {
                        content.forEach { (key, value) ->
                            when (value) {
                                is String -> put(key, value)
                                is Number -> put(key, JsonPrimitive(value))
                                is Boolean -> put(key, value)
                                else -> put(key, value.toString())
                            }
                        }
                    }
                    
                    val message = BridgeMessage(
                        data = MessageData(
                            action = action,
                            content = contentJson
                        ),
                        id = id
                    )
                    
                    val messageJson = json.encodeToString(message)
                    
                    if (debugEnabled) {
                        Log.d(TAG, "Calling web: $messageJson")
                    }
                    
                    // Setup timeout (30 seconds)
                    mainHandler.postDelayed(timeoutRunnable, 30000)
                    
                    val js = "window.bridge._onNativeMessage($messageJson)"
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
    private fun handleWebResponse(response: BridgeResponse) {
        try {
            val pending = pendingRequests.remove(response.id)
            
            if (pending != null) {
                // Cancel the timeout
                mainHandler.removeCallbacks(pending.timeoutRunnable)
                
                // Resume the continuation with result or error
                if (response.error != null) {
                    pending.continuation.resumeWithException(
                        Exception(response.error.message)
                    )
                } else {
                    pending.continuation.resume(response.result ?: buildJsonObject {})
                }
            } else {
                Log.w(TAG, "Received response for unknown request ID: ${response.id}")
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
