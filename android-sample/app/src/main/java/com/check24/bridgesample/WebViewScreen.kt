package com.check24.bridgesample

import android.annotation.SuppressLint
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.check24.bridgesample.bridge.DefaultBridgeMessageHandler
import com.check24.bridgesample.bridge.JavaScriptBridge
import timber.log.Timber

@Composable
fun WebViewScreen(
    modifier: Modifier = Modifier,
    url: String,
    onBridgeReady: (JavaScriptBridge) -> Unit
) {
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            WebView(ctx).apply {
                @SuppressLint("SetJavaScriptEnabled")
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(
                        view: WebView?,
                        request: WebResourceRequest?
                    ): Boolean {
                        return false
                    }

                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        Timber.d("WebView loaded: $url")
                        // Ensure bridge script is injected after page load
                        (view?.tag as? JavaScriptBridge)?.injectBridgeScript()
                    }
                }

                // Attach bridge
                val bridge = JavaScriptBridge(this, DefaultBridgeMessageHandler())
                addJavascriptInterface(bridge, JavaScriptBridge.BRIDGE_NAME)
                tag = bridge
                onBridgeReady(bridge)
                loadUrl(url)
            }
        },
        update = { view ->
            if (view.url != url) {
                view.loadUrl(url)
            }
        }
    )
}