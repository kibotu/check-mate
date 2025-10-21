package com.check24.bridgesample.bridge.commands.systembars

import com.check24.bridgesample.bridge.commands.utils.BridgeParsingUtils
import com.check24.bridgesample.bridge.commands.utils.BridgeResponseUtils
import com.github.florent37.application.provider.ActivityProvider
import de.check24.profis.partner.pluginapi.features.webview.bridge.commands.BridgeCommand
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import timber.log.Timber

/**
 * Controls Android system UI (status/navigation bars) for immersive experiences.
 *
 * **Why web needs this:**
 * Web cannot control native system UI bars. Needed for:
 * - Full-screen media viewing (hide bars for immersive video/images)
 * - Games or interactive content requiring maximum screen space
 * - Specific UX flows where native chrome should disappear
 *
 * **Why separate controls:**
 * Status bar (top) and navigation bar (bottom) serve different purposes.
 * Some flows want full-screen but keep navigation for usability.
 *
 * **Why Dispatchers.Main:**
 * Window property modifications must happen on UI thread. Android will crash otherwise.
 */
class SystemBarsCommand : BridgeCommand {

    override val action = "systemBars"

    override suspend fun handle(content: Any?): JSONObject = withContext(Dispatchers.Main) {
        try {
            val showStatusBar = BridgeParsingUtils.parseBoolean(content, "showStatusBar")
            val showSystemNavigation =
                BridgeParsingUtils.parseBoolean(content, "showSystemNavigation")

            Timber.i("[handle] showStatusBar=$showStatusBar showSystemNavigation=$showSystemNavigation")

            val activity = ActivityProvider.currentActivity
                ?: return@withContext BridgeResponseUtils.createErrorResponse(
                    "NO_ACTIVITY",
                    "No active activity"
                )

            activity.window?.showSystemStatusBar = showStatusBar
            activity.window?.showSystemNavigationBar = showSystemNavigation

            BridgeResponseUtils.createSuccessResponse()
        } catch (e: Exception) {
            BridgeResponseUtils.createErrorResponse(
                "SYSTEM_BARS_FAILED",
                e.message ?: "Failed to configure system bars"
            )
        }
    }
}

