package com.check24.bridgesample.bridge

/**
 * Interface for handling bridge messages from JavaScript.
 */
interface BridgeMessageHandler {
    /**
     * Handle a message from JavaScript.
     *
     * @param action The action to perform
     * @param content Optional content for the action
     * @return The result to send back to JavaScript, or null for fire-and-forget
     */
    suspend fun handle(action: String, content: Any?): Any?
}
