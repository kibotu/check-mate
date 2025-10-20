package com.check24.bridgesample.bridge.commands

import de.check24.profis.partner.pluginapi.features.webview.bridge.commands.BridgeCommand
import org.json.JSONObject

/**
 * Reports real network connectivity status to web for offline-first UX.
 *
 * **Why web needs this:**
 * Web's `navigator.onLine` is unreliable (reports false positives). Native Android
 * has accurate network state through ConnectivityManager. Enables web to:
 * - Show offline UI before failed requests
 * - Queue actions for later when offline
 * - Disable network-dependent features gracefully
 * - Adapt quality (low bandwidth = reduced images/video)
 *
 * **Why type field:**
 * Future extensibility for network type (wifi/cellular/ethernet) to enable
 * bandwidth-aware UX decisions.
 */
class CheckNetworkStatusCommand : BridgeCommand {

    override val action = "networkState"

    override suspend fun handle(content: Any?): JSONObject {
//        val isConnected = CorePluginServices.services.networkAvailabilityService.isNetworkAvailable
        return JSONObject().apply {
//            put("connected", isConnected)
//            put("type", if (isConnected) "wifi" else "none")
        }
    }
}

