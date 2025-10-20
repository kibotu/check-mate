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
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Divider
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScaffoldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.check24.bridgesample.bridge.DefaultBridgeMessageHandler
import com.check24.bridgesample.bridge.JavaScriptBridge
import com.check24.bridgesample.bridge.TopNavigationService
import com.check24.bridgesample.bridge.BottomNavigationService
import timber.log.Timber
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import com.check24.bridgesample.bridge.commands.utils.isLightNavigationBar
import com.check24.bridgesample.bridge.commands.utils.isLightStatusBar

class MainActivity : ComponentActivity() {
    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {

        enableEdgeToEdge()

        window?.isLightNavigationBar = true
        window?.isLightStatusBar = true

        super.onCreate(savedInstanceState)


        setContent {
            var selectedTabIndex by remember { mutableIntStateOf(0) }
            val navController = rememberNavController()
            val topNavConfig by TopNavigationService.config.collectAsState()
            val isBottomBarVisible by BottomNavigationService.isVisible.collectAsState()

            LaunchedEffect(selectedTabIndex) {
                when (selectedTabIndex) {
                    0 -> navController.navigate("tab1") {
                        popUpTo(navController.graph.startDestinationId) {
                            inclusive = true
                        }
                    }

                    1 -> navController.navigate("tab2") {
                        popUpTo(navController.graph.startDestinationId) {
                            inclusive = true
                        }
                    }
                }
            }

            Box(modifier = Modifier.fillMaxSize()) {
            Scaffold(
                modifier = Modifier.fillMaxSize(),
                contentWindowInsets = WindowInsets(0),
                topBar = {
                    Column(modifier = Modifier.animateContentSize()) {
                        if (topNavConfig.isVisible) {
                            Column(modifier = Modifier.windowInsetsPadding(WindowInsets.statusBars)) {
                                TopAppBar(
                                    title = {
                                        val titleText = if (topNavConfig.showLogo) {
                                            "CHECK24"
                                        } else {
                                            topNavConfig.title ?: "Check-Mate Bridge Sample"
                                        }
                                        Text(text = titleText)
                                    },
                                    navigationIcon = {
                                        if (topNavConfig.showUpArrow) {
                                            IconButton(onClick = { onBackPressedDispatcher.onBackPressed() }) {
                                                Icon(
                                                    imageVector = Icons.Filled.ArrowBack,
                                                    contentDescription = "Back"
                                                )
                                            }
                                        }
                                    },
                                    actions = {
                                        if (topNavConfig.showProfileIconWidget) {
                                            Icon(
                                                imageVector = Icons.Filled.Person,
                                                contentDescription = "Profile"
                                            )
                                        }
                                    }
                                )
                                if (topNavConfig.showDivider) {
                                    Divider()
                                }
                            }
                        }
                    }
                },
                bottomBar = { }
            ) { paddingValues ->
                NavHost(
                    navController = navController,
                    startDestination = "tab1",
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .animateContentSize()
                ) {
                    composable("tab1") { WebViewScreen(url = "file:///android_asset/index.html") }
                    composable("tab2") { WebViewScreen(url = "https://portfolio.kibotu.net/") }
                }
            }
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
            ) {
                Column {
                    AnimatedVisibility(
                        visible = isBottomBarVisible,
                        enter = slideInVertically(initialOffsetY = { it }),
                        exit = slideOutVertically(targetOffsetY = { it })
                    ) {
                        NavigationBar(containerColor = Color.White, windowInsets = WindowInsets(0)) {
                            NavigationBarItem(
                                selected = selectedTabIndex == 0,
                                onClick = { selectedTabIndex = 0 },
                                label = { Text("Assets") },
                                icon = { Icon(imageVector = Icons.Filled.Home, contentDescription = null) }
                            )
                            NavigationBarItem(
                                selected = selectedTabIndex == 1,
                                onClick = { selectedTabIndex = 1 },
                                label = { Text("Portfolio") },
                                icon = { Icon(imageVector = Icons.Filled.Public, contentDescription = null) }
                            )
                        }
                    }
                }
            }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun WebViewScreen(url: String) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            WebView(ctx).apply {
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
