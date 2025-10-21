package com.check24.bridgesample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.lifecycle.lifecycleScope
import com.check24.bridgesample.bridge.JavaScriptBridge
import com.check24.bridgesample.bridge.commands.refresh.RefreshService
import com.check24.bridgesample.bridge.commands.systembars.isLightNavigationBar
import com.check24.bridgesample.bridge.commands.systembars.isLightStatusBar
import com.check24.bridgesample.misc.weak
import com.check24.bridgesample.ui.Screen
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber
import kotlin.random.Random

class MainActivity : ComponentActivity() {

    private var currentBridge: JavaScriptBridge? by weak()

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {

        enableEdgeToEdge()

        window?.isLightNavigationBar = true
        window?.isLightStatusBar = true

        super.onCreate(savedInstanceState)

        setContent {
            Screen(
                onBackPressed = {
                    onBackPressedDispatcher.onBackPressed()
                },
                onBridgeReady = { currentBridge = it }
            )
        }

        // random events emulating pushes
        lifecycleScope.launch {
            while (true) {
                delay(Random.nextLong(7000, 15000))
                currentBridge?.sendToWeb(
                    "onPushNotification",
                    mapOf(
                        "url" to "https://www.google.com",
                        "message" to "Lorem Ipsum"
                    )
                )
            }
        }

        // listen to when web wants to refresh native
        lifecycleScope.launch {
            RefreshService.onRefresh.collect {
                Timber.v("refreshing $it")
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        val event = if (hasFocus) "focused" else "defocused"
        currentBridge?.sendToWeb("lifecycle", mapOf("event" to event))
    }
}

