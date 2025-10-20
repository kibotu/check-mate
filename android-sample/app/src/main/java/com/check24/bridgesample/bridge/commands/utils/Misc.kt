package com.check24.bridgesample.bridge.commands.utils

import androidx.appcompat.app.AppCompatActivity
import com.github.florent37.application.provider.ActivityProvider


val currentAppCompatActivity: AppCompatActivity?
    get() = ActivityProvider.currentActivity as? AppCompatActivity

