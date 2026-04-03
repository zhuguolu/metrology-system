package com.metrology.app

import android.content.Context
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatActivity
import kotlin.math.abs

private const val APP_FONT_SCALE = 0.92f

abstract class FontScaleActivity : AppCompatActivity() {
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(newBase.withAppFontScale(APP_FONT_SCALE))
    }
}

private fun Context.withAppFontScale(scale: Float): Context {
    val current = resources.configuration.fontScale
    if (abs(current - scale) < 0.001f) return this
    val config = Configuration(resources.configuration)
    config.fontScale = scale
    return createConfigurationContext(config)
}
