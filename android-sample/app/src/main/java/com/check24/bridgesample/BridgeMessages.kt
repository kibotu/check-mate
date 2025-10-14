package com.check24.bridgesample

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Data classes for bridge messages using Kotlin Serialization
 */

@Serializable
data class BridgeMessage(
    val data: MessageData,
    val id: String? = null
)

@Serializable
data class MessageData(
    val action: String,
    val content: JsonElement? = null
)

@Serializable
data class BridgeResponse(
    val id: String,
    val result: JsonElement? = null,
    val error: BridgeError? = null
)

@Serializable
data class BridgeError(
    val code: String,
    val message: String
)

@Serializable
data class EventMessage(
    val data: MessageData
)

