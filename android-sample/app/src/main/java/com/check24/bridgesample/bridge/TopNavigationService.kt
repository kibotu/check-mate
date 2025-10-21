package com.check24.bridgesample.bridge

import com.check24.bridgesample.bridge.commands.TopNavigationConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Holds top navigation configuration so it can be controlled by bridge commands. */
object TopNavigationService {
    private val _config: MutableStateFlow<TopNavigationConfig> = MutableStateFlow(TopNavigationConfig())
    val config: StateFlow<TopNavigationConfig> = _config

    fun applyConfig(newConfig: TopNavigationConfig) {
        _config.value = newConfig
    }

    fun reset() {
        _config.value = TopNavigationConfig()
    }
}


