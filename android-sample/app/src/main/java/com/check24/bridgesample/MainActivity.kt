package com.check24.bridgesample

import android.annotation.SuppressLint
import android.os.Bundle
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    
    private lateinit var webView: WebView
    private lateinit var bridge: BridgeInterface
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        webView = findViewById(R.id.webView)
        setupWebView()
        setupBackPressHandler()
        
        // Load the sample HTML from assets
        webView.loadUrl("file:///android_asset/index.html")
        
        // Demo: Send an event to web after 5 seconds
        lifecycleScope.launch {
            delay(5000)
            sendDemoEvent()
        }
    }
    
    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = true
            allowContentAccess = true
        }
        
        // Setup bridge
        bridge = BridgeInterface(webView)
        bridge.setDebug(true) // Enable debug logging
        webView.addJavascriptInterface(bridge, "AndroidBridge")
        
        // Setup WebViewClient
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Log.d(TAG, "Page loaded: $url")
            }
        }
        
        // Setup WebChromeClient for console logging
        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                Log.d(TAG, "WebView Console: ${consoleMessage.message()} " +
                        "-- From line ${consoleMessage.lineNumber()} " +
                        "of ${consoleMessage.sourceId()}")
                return true
            }
        }
    }
    
    /**
     * Setup back press handler to navigate WebView history
     */
    private fun setupBackPressHandler() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    // No more history, allow default back behavior
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }
    
    /**
     * Demo: Send an event from native to web
     */
    private fun sendDemoEvent() {
        bridge.sendEventToWeb(
            action = "nativeEvent",
            content = mapOf(
                "type" to "demo",
                "message" to "Hello from Android!",
                "timestamp" to System.currentTimeMillis()
            )
        )
        Log.i(TAG, "Sent demo event to web")
    }
    
    /**
     * Demo: Call web and wait for response
     * This shows how native can call into web and await a response
     */
    private fun callWebDemo() {
        lifecycleScope.launch {
            try {
                val result = bridge.callWeb(
                    action = "getWebState",
                    content = mapOf("query" to "current_state")
                )
                Log.i(TAG, "Web response: $result")
            } catch (e: Exception) {
                Log.e(TAG, "Error calling web", e)
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        webView.destroy()
    }
}

