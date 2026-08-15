package com.example.progressive_webview_app

import android.content.Context
import android.content.SharedPreferences

class RemoteConfigManager private constructor(context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREF_NAME = "cricket_batting_prefs_v1"
        private const val KEY_TARGET_URL = "remote_target_url"
        private const val KEY_FIRST_LAUNCH = "is_first_launch_v1"
        private const val KEY_SESSION_TIMESTAMP = "session_start_timestamp_v1"
        private const val KEY_DARK_MODE = "is_dark_mode_v1"
        const val DEFAULT_TARGET_URL = "https://stables365.com/"
        const val SESSION_DURATION_HOURS = 72

        @Volatile
        private var instance: RemoteConfigManager? = null

        fun getInstance(context: Context): RemoteConfigManager {
            return instance ?: synchronized(this) {
                instance ?: RemoteConfigManager(context.applicationContext).also { instance = it }
            }
        }
    }

    /**
     * Get persisted or default target URL
     */
    fun getTargetUrl(): String {
        return prefs.getString(KEY_TARGET_URL, DEFAULT_TARGET_URL) ?: DEFAULT_TARGET_URL
    }

    /**
     * Save dynamic target URL
     */
    fun saveTargetUrl(url: String): Boolean {
        return prefs.edit().putString(KEY_TARGET_URL, url).commit()
    }

    /**
     * Initialize or validate 72-hour session persistence
     * Returns true if session is still within 72 hours, false if expired & refreshed
     */
    fun initOrValidateSession(): Boolean {
        val lastTimestamp = prefs.getLong(KEY_SESSION_TIMESTAMP, 0L)
        val nowMs = System.currentTimeMillis()

        if (lastTimestamp == 0L) {
            prefs.edit().putLong(KEY_SESSION_TIMESTAMP, nowMs).apply()
            return true
        }

        val elapsedHours = (nowMs - lastTimestamp).toDouble() / (1000 * 60 * 60)
        return if (elapsedHours >= SESSION_DURATION_HOURS) {
            prefs.edit().putLong(KEY_SESSION_TIMESTAMP, nowMs).apply()
            false
        } else {
            true
        }
    }

    /**
     * Get remaining hours in current 72-hour session
     */
    fun getRemainingSessionHours(): Int {
        val lastTimestamp = prefs.getLong(KEY_SESSION_TIMESTAMP, 0L)
        if (lastTimestamp == 0L) return SESSION_DURATION_HOURS

        val elapsedHours = (System.currentTimeMillis() - lastTimestamp).toDouble() / (1000 * 60 * 60)
        val remaining = SESSION_DURATION_HOURS - elapsedHours.toInt()
        return if (remaining > 0) remaining else 0
    }

    /**
     * Refresh 72-hour session explicitly
     */
    fun refreshSession() {
        prefs.edit().putLong(KEY_SESSION_TIMESTAMP, System.currentTimeMillis()).apply()
    }

    /**
     * First launch check & flag
     */
    fun isFirstLaunch(): Boolean {
        return prefs.getBoolean(KEY_FIRST_LAUNCH, true)
    }

    fun setFirstLaunchCompleted() {
        prefs.edit().putBoolean(KEY_FIRST_LAUNCH, false).apply()
    }

    /**
     * Theme preference (Dark / Light)
     */
    fun isDarkMode(): Boolean {
        return prefs.getBoolean(KEY_DARK_MODE, true) // Default to dark theme
    }

    fun setDarkMode(isDark: Boolean) {
        prefs.edit().putBoolean(KEY_DARK_MODE, isDark).apply()
    }
}
