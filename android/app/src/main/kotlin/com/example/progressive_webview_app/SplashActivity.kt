package com.example.progressive_webview_app

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.example.progressive_webview_app.databinding.ActivitySplashBinding

@SuppressLint("CustomSplashScreen")
class SplashActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySplashBinding
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySplashBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Validate 72-hour session
        val remoteConfig = RemoteConfigManager.getInstance(this)
        remoteConfig.initOrValidateSession()
        val remainingHours = remoteConfig.getRemainingSessionHours()
        binding.tvSessionBadge.text = "${remainingHours}H SECURE SESSION"

        // Setup Entry Animations
        binding.heroCard.alpha = 0f
        binding.heroCard.scaleX = 0.88f
        binding.heroCard.scaleY = 0.88f

        binding.tvTitle.alpha = 0f
        binding.tvTitle.translationY = 20f

        binding.tvSubtitle.alpha = 0f
        binding.badgeLayout.alpha = 0f

        binding.heroCard.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(900)
            .setInterpolator(OvershootInterpolator(1.1f))
            .start()

        binding.tvTitle.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(700)
            .setStartDelay(250)
            .start()

        binding.tvSubtitle.animate()
            .alpha(1f)
            .setDuration(700)
            .setStartDelay(350)
            .start()

        binding.badgeLayout.animate()
            .alpha(1f)
            .setDuration(700)
            .setStartDelay(450)
            .start()

        // Transition to MainActivity after splash duration (1200ms)
        handler.postDelayed({
            if (!isFinishing && !isDestroyed) {
                startActivity(Intent(this, MainActivity::class.java))
                finish()
                overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
            }
        }, 1200)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
