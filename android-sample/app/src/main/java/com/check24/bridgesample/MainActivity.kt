package com.check24.bridgesample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.ExperimentalMaterial3Api
import com.check24.bridgesample.bridge.JavaScriptBridge
import com.check24.bridgesample.misc.isLightNavigationBar
import com.check24.bridgesample.misc.isLightStatusBar
import com.check24.bridgesample.misc.weak
import com.check24.bridgesample.ui.Screen

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
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        val event = if (hasFocus) "focused" else "defocused"
        currentBridge?.sendToWeb("lifecycle", mapOf("event" to event))
    }
}

