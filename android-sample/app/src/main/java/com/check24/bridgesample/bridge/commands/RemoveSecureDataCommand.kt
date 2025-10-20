package com.check24.bridgesample.bridge.commands

import com.check24.bridgesample.bridge.commands.utils.BridgeParsingUtils
import com.check24.bridgesample.bridge.commands.utils.BridgeResponseUtils
import de.check24.profis.partner.pluginapi.features.webview.bridge.commands.BridgeCommand
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import timber.log.Timber

/**
 * Deletes sensitive data from Android's encrypted storage.
 *
 * **Why web needs this:**
 * Critical for:
 * - User logout (clear auth tokens, session data)
 * - Data privacy (remove cached sensitive info)
 * - Storage management (clean up obsolete data)
 * - Security best practice (don't keep data longer than needed)
 *
 * **Why separate from save:**
 * Explicit deletion operation makes security-critical actions visible in code.
 * Can't accidentally delete by saving null/empty (explicit is better than implicit).
 *
 * **Why Dispatchers.IO:**
 * Storage deletion is disk I/O operation, should not block main thread.
 *
 * **Common use cases:**
 * - Logout flow: remove all auth tokens
 * - Privacy compliance: user requests data deletion
 * - Session management: clear expired/invalid tokens
 */
class RemoveSecureDataCommand : BridgeCommand {

    override val action = "removeSecureData"

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
            BridgeResponseUtils.createSuccessResponse()
        } catch (e: Exception) {
            Timber.e(e)
            BridgeResponseUtils.createErrorResponse(
                "REMOVE_FAILED",
                e.message ?: "Failed to remove data"
            )
        }
    }
}