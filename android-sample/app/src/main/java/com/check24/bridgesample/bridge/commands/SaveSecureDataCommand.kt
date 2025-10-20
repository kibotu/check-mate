package com.check24.bridgesample.bridge.commands

import com.check24.bridgesample.bridge.commands.utils.BridgeParsingUtils
import com.check24.bridgesample.bridge.commands.utils.BridgeResponseUtils
import de.check24.profis.partner.pluginapi.features.webview.bridge.commands.BridgeCommand
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import timber.log.Timber

/**
 * Persists sensitive data to Android's encrypted storage.
 *
 * **Why web needs this:**
 * Web's localStorage/sessionStorage are NOT secure:
 * - Stored as plaintext (accessible via adb, root, file explorers)
 * - Can be read by malicious JavaScript
 * - Not encrypted at rest
 * Native encrypted storage protects sensitive data using Android Keystore.
 *
 * **Why encrypted storage:**
 * Critical for storing:
 * - Authentication tokens/refresh tokens
 * - User credentials (if needed)
 * - API keys
 * - PII that should never be in plaintext
 *
 * **Why Dispatchers.IO:**
 * Storage operations are I/O bound. IO dispatcher optimized for blocking
 * operations, prevents blocking main thread during disk writes.
 *
 * **Why key-value model:**
 * Simple, familiar pattern (like localStorage API). Web developers understand
 * key-value storage immediately, reducing learning curve.
 *
 * **Implementation placeholder:**
 * Awaits integration with actual EncryptedSharedPreferences or Keystore-based
 * storage solution. Currently logs for development/debugging.
 */
class SaveSecureDataCommand : BridgeCommand {

    override val action = "saveSecureData"

    override suspend fun handle(content: Any?): JSONObject = withContext(Dispatchers.IO) {
        val key = BridgeParsingUtils.parseString(content, "key")
        BridgeParsingUtils.parseString(content, "value")

        if (key.isEmpty()) {
            return@withContext BridgeResponseUtils.createErrorResponse(
                "INVALID_PARAMETER",
                "Missing 'key' parameter"
            )
        }

        try {
            // You can integrate with your secure storage system here
            Timber.i("[handle] key=$key")
            BridgeResponseUtils.createSuccessResponse()
        } catch (e: Exception) {
            Timber.e(e)
            BridgeResponseUtils.createErrorResponse(
                "SAVE_FAILED",
                e.message ?: "Failed to save data"
            )
        }
    }
}

