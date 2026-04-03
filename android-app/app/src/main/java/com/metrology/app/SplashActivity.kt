package com.metrology.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class SplashActivity : FontScaleActivity() {

    private val launchTask = Runnable {
        val loggedIn = runCatching { AppGraph.repository.isLoggedIn() }.getOrDefault(false)
        val target = if (loggedIn) MainActivity::class.java else LoginActivity::class.java
        startActivity(Intent(this, target))
        finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_splash)
        applyInsets()
        playEnterAnimation()
        window.decorView.postDelayed(launchTask, SPLASH_DURATION_MS)
    }

    private fun applyInsets() {
        val root = findViewById<android.view.View>(R.id.splashRoot)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                20 + systemBars.left,
                20 + systemBars.top,
                20 + systemBars.right,
                20 + systemBars.bottom
            )
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun playEnterAnimation() {
        val content = findViewById<android.view.View>(R.id.splashContent)
        val logo = findViewById<android.view.View>(R.id.logoChip)
        val loading = findViewById<android.view.View>(R.id.splashLoading)

        content.alpha = 0f
        content.translationY = 28f
        logo.scaleX = 0.9f
        logo.scaleY = 0.9f
        loading.alpha = 0f

        content.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(360L)
            .start()

        logo.animate()
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(360L)
            .start()

        loading.animate()
            .alpha(1f)
            .setStartDelay(160L)
            .setDuration(260L)
            .start()
    }

    override fun onDestroy() {
        window.decorView.removeCallbacks(launchTask)
        super.onDestroy()
    }

    companion object {
        private const val SPLASH_DURATION_MS = 520L
    }
}
