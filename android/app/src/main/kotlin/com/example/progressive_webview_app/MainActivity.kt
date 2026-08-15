package com.example.progressive_webview_app

import android.app.Dialog
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import com.example.progressive_webview_app.databinding.ActivityMainBinding
import com.example.progressive_webview_app.databinding.DialogChangeUrlBinding

class MainActivity : AppCompatActivity(), NativeWebViewEngine.WebViewEventListener {

    private lateinit var binding: ActivityMainBinding
    private lateinit var webEngine: NativeWebViewEngine
    private lateinit var remoteConfig: RemoteConfigManager

    private var filePathCallback: ValueCallback<Array<Uri>>? = null
    private var isFullscreenMode: Boolean = false

    private val filePickerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (filePathCallback != null) {
            val results: Array<Uri>? = if (result.resultCode == RESULT_OK) {
                result.data?.data?.let { arrayOf(it) }
                    ?: result.data?.clipData?.let { clip ->
                        Array(clip.itemCount) { i -> clip.getItemAt(i).uri }
                    }
            } else null
            filePathCallback?.onReceiveValue(results)
            filePathCallback = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        remoteConfig = RemoteConfigManager.getInstance(this)

        setupThemeState()
        setupWebView()
        setupToolbarActions()
        setupBackNavigation()
    }

    private fun setupThemeState() {
        val isDark = remoteConfig.isDarkMode()
        if (isDark) {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        } else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        }
    }

    private fun setupWebView() {
        webEngine = NativeWebViewEngine(this, binding.mainWebView, this)

        // Setup Swipe to refresh
        binding.swipeRefreshLayout.setColorSchemeColors(
            ContextCompat.getColor(this, R.color.primary),
            ContextCompat.getColor(this, R.color.accent)
        )
        binding.swipeRefreshLayout.setOnRefreshListener {
            webEngine.reload()
        }

        // Error retry button
        binding.btnErrorRetry.setOnClickListener {
            binding.errorViewContainer.visibility = View.GONE
            binding.swipeRefreshLayout.visibility = View.VISIBLE
            webEngine.loadUrl(remoteConfig.getTargetUrl())
        }

        // Load initial target URL
        webEngine.loadUrl(remoteConfig.getTargetUrl())
    }

    private fun setupToolbarActions() {
        // Back
        binding.btnBack.setOnClickListener {
            if (webEngine.canGoBack()) {
                webEngine.goBack()
            } else {
                Toast.makeText(this, "No previous page", Toast.LENGTH_SHORT).show()
            }
        }

        // Forward
        binding.btnForward.setOnClickListener {
            if (webEngine.canGoForward()) {
                webEngine.goForward()
            } else {
                Toast.makeText(this, "No forward page", Toast.LENGTH_SHORT).show()
            }
        }

        // Refresh
        binding.btnRefresh.setOnClickListener {
            webEngine.reload()
        }

        // Home
        binding.btnHome.setOnClickListener {
            webEngine.loadUrl(remoteConfig.getTargetUrl())
        }

        // Change Target URL Dialog
        binding.btnChangeUrl.setOnClickListener {
            showChangeUrlDialog()
        }

        // Theme Toggle
        binding.btnThemeToggle.setOnClickListener {
            toggleTheme()
        }

        // Fullscreen Toggle
        binding.btnFullscreen.setOnClickListener {
            toggleFullscreen(true)
        }

        // Floating Exit Fullscreen Button
        binding.fabExitFullscreen.setOnClickListener {
            toggleFullscreen(false)
        }
    }

    private fun toggleFullscreen(enable: Boolean) {
        isFullscreenMode = enable
        if (enable) {
            binding.topToolbar.visibility = View.GONE
            binding.fabExitFullscreen.visibility = View.VISIBLE
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        } else {
            binding.topToolbar.visibility = View.VISIBLE
            binding.fabExitFullscreen.visibility = View.GONE
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        }
    }

    private fun toggleTheme() {
        val currentIsDark = remoteConfig.isDarkMode()
        val newIsDark = !currentIsDark
        remoteConfig.setDarkMode(newIsDark)
        if (newIsDark) {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        } else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        }
    }

    private fun showChangeUrlDialog() {
        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        val dialogBinding = DialogChangeUrlBinding.inflate(layoutInflater)
        dialog.setContentView(dialogBinding.root)
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.90).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )

        dialogBinding.etTargetUrl.setText(remoteConfig.getTargetUrl())

        dialogBinding.btnResetDefault.setOnClickListener {
            dialogBinding.etTargetUrl.setText(RemoteConfigManager.DEFAULT_TARGET_URL)
        }

        dialogBinding.btnCancelUrl.setOnClickListener {
            dialog.dismiss()
        }

        dialogBinding.btnSaveUrl.setOnClickListener {
            var inputUrl = dialogBinding.etTargetUrl.text?.toString()?.trim() ?: ""
            if (inputUrl.isNotEmpty()) {
                if (!inputUrl.startsWith("http://") && !inputUrl.startsWith("https://")) {
                    inputUrl = "https://$inputUrl"
                }
                remoteConfig.saveTargetUrl(inputUrl)
                webEngine.loadUrl(inputUrl)
                Toast.makeText(this, "Target URL updated", Toast.LENGTH_SHORT).show()
                dialog.dismiss()
            } else {
                dialogBinding.urlInputLayout.error = "Please enter a valid URL"
            }
        }

        dialog.show()
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (isFullscreenMode) {
                    toggleFullscreen(false)
                } else if (webEngine.canGoBack()) {
                    webEngine.goBack()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    // ==========================================
    // NativeWebViewEngine Listener Callbacks
    // ==========================================

    override fun onProgressChanged(progress: Int) {
        if (progress < 100) {
            binding.pageProgressBar.visibility = View.VISIBLE
            binding.pageProgressBar.progress = progress
        } else {
            binding.pageProgressBar.visibility = View.GONE
            binding.swipeRefreshLayout.isRefreshing = false
        }
    }

    override fun onTitleReceived(title: String) {
        if (title.isNotBlank()) {
            binding.tvToolbarTitle.text = title
        }
    }

    override fun onPageStarted(url: String) {
        binding.pageProgressBar.visibility = View.VISIBLE
        binding.statusDot.setBackgroundResource(R.drawable.bg_status_dot)
    }

    override fun onPageFinished(url: String) {
        binding.pageProgressBar.visibility = View.GONE
        binding.swipeRefreshLayout.isRefreshing = false
        binding.errorViewContainer.visibility = View.GONE
        binding.swipeRefreshLayout.visibility = View.VISIBLE
    }

    override fun onErrorReceived(errorCode: Int, description: String, failingUrl: String) {
        binding.pageProgressBar.visibility = View.GONE
        binding.swipeRefreshLayout.isRefreshing = false
        binding.tvErrorDesc.text = "$description\n($failingUrl)"
        binding.errorViewContainer.visibility = View.VISIBLE
        binding.swipeRefreshLayout.visibility = View.GONE
    }

    override fun onPopupOpened(message: String) {
        // Website popup window handled inside webview
    }

    override fun onPopupAutoClosed(message: String) {
        // Betting 2-second dialog auto-closed & reloaded
    }

    override fun onFileChooserRequested(
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: WebChromeClient.FileChooserParams?
    ): Boolean {
        this.filePathCallback?.onReceiveValue(null)
        this.filePathCallback = filePathCallback

        val intent = fileChooserParams?.createIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }

        try {
            filePickerLauncher.launch(intent)
            return true
        } catch (e: Exception) {
            this.filePathCallback = null
            return false
        }
    }

    override fun onDestroy() {
        webEngine.destroy()
        super.onDestroy()
    }
}
