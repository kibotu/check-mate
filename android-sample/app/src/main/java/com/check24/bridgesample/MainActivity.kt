package com.check24.bridgesample

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.check24.bridgesample.bridge.DefaultBridgeMessageHandler
import com.check24.bridgesample.bridge.JavaScriptBridge
import timber.log.Timber
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Public

class MainActivity : ComponentActivity() {
    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var selectedTabIndex by remember { mutableIntStateOf(0) }
            val navController = rememberNavController()

            LaunchedEffect(selectedTabIndex) {
                when (selectedTabIndex) {
                    0 -> navController.navigate("tab1") { popUpTo(navController.graph.startDestinationId) { inclusive = true } }
                    1 -> navController.navigate("tab2") { popUpTo(navController.graph.startDestinationId) { inclusive = true } }
                }
            }

            Scaffold(
                modifier = Modifier.fillMaxSize(),
                topBar = {
                    TopAppBar(title = { Text(text = "Check-Mate Bridge Sample") })
                },
            ) { paddingValues ->
                Column(modifier = Modifier.fillMaxSize()) {
                    TabRow(selectedTabIndex = selectedTabIndex) {
                        Tab(
                            selected = selectedTabIndex == 0,
                            onClick = { selectedTabIndex = 0 },
                            text = { Text("Assets") },
                            icon = { Icon(imageVector = Icons.Filled.Home, contentDescription = null) }
                        )
                        Tab(
                            selected = selectedTabIndex == 1,
                            onClick = { selectedTabIndex = 1 },
                            text = { Text("Portfolio") },
                            icon = { Icon(imageVector = Icons.Filled.Public, contentDescription = null) }
                        )
                    }
                    NavHost(
                        navController = navController,
                        startDestination = "tab1",
                        modifier = Modifier.fillMaxSize()
                    ) {
                        composable("tab1") { WebViewScreen(url = "file:///android_asset/index.html") }
                        composable("tab2") { WebViewScreen(url = "https://portfolio.kibotu.net/") }
                    }
                }
            }
        }
    }
}

@Composable
private fun WebViewScreen(url: String) {
    val context = LocalContext.current
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            @SuppressLint("SetJavaScriptEnabled")
            WebView(ctx).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
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
