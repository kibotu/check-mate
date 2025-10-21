package com.check24.bridgesample.bridge.commands.topnavigation

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Simple holder for the current top navigation configuration so it can be
 * updated by bridge commands and observed by UI (e.g., MainActivity).
 */
object TopNavigationService {
    private val _config: MutableStateFlow<TopNavigationConfig> =
        MutableStateFlow(TopNavigationConfig())
    val config: StateFlow<TopNavigationConfig> = _config

    fun applyConfig(newConfig: TopNavigationConfig) {
        _config.value = newConfig
    }
}