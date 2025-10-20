package com.check24.bridgesample.bridge

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Holds bottom navigation visibility so it can be controlled by bridge commands. */
object BottomNavigationService {
    private val _isVisible: MutableStateFlow<Boolean> = MutableStateFlow(true)
    val isVisible: StateFlow<Boolean> = _isVisible

    fun setVisible(visible: Boolean) {
        _isVisible.value = visible
    }
}


