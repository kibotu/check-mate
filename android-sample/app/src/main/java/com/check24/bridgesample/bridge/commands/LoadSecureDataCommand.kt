package com.check24.bridgesample.bridge.commands

import com.check24.bridgesample.bridge.commands.utils.BridgeParsingUtils
import com.check24.bridgesample.bridge.commands.utils.BridgeResponseUtils
import de.check24.profis.partner.pluginapi.features.webview.bridge.commands.BridgeCommand
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import timber.log.Timber

/**
 * Retrieves sensitive data from Android's encrypted storage.
 *
 * **Why web needs this:**
 * Counterpart to SaveSecureDataCommand. Web needs to retrieve previously stored
 * encrypted data (auth tokens, user settings, etc.) for:
 * - Session restoration across app restarts
 * - Authenticated API calls
 * - Persisting user preferences securely
 *
 * **Why nullable value:**
 * Returns null if key doesn't exist, allowing web to detect first-time use
 * vs. stored data. Follows familiar pattern of localStorage.getItem().
 *
 * **Why Dispatchers.IO:**
 * Reading encrypted data involves disk I/O and potentially decryption.
 * IO dispatcher prevents blocking UI during these operations.
 *
 * **Security consideration:**
 * Only web code from your domain should access this bridge. WebView's
 * origin-based security model prevents unauthorized access.
 */
class LoadSecureDataCommand : BridgeCommand {

    override val action = "loadSecureData"

    override suspend fun handle(content: Any?): JSONObject = withContext(Dispatchers.IO) {
        val key = BridgeParsingUtils.parseString(content, "key")

        if (key.isEmpty()) {
            return@withContext BridgeResponseUtils.createErrorResponse(
                "INVALID_PARAMETER",
                "Missing 'key' parameter"
            )
        }

        try {
            // You can integrate with your secure storage system here
            Timber.i("[handle] key=$key")
            JSONObject().apply {
                put("key", key)
                put("value", null) // Return null if not found
            }
        } catch (e: Exception) {
            Timber.e(e)
            BridgeResponseUtils.createErrorResponse(
                "LOAD_FAILED",
                e.message ?: "Failed to load data"
            )
        }
    }
}