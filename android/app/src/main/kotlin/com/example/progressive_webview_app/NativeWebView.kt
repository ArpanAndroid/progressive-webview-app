package com.example.progressive_webview_app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.view.View
import android.webkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class NativeWebView(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    params: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val webView: WebView = WebView(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.example.progressive_webview/native_webview_$id")
    private var popupAutoCloseDelayMs: Long = 1000L // Fast 1-second auto-close when active
    private var isTurboBetActive: Boolean = true

    init {
        methodChannel.setMethodCallHandler(this)
        configureWebViewSettings()
        setupWebViewClients()

        val initialUrl = params?.get("initialUrl") as? String ?: "https://stables365.com/cricket-betting/1793/1705297"
        val headers = params?.get("headers") as? Map<String, String>
        if (headers != null && headers.isNotEmpty()) {
            webView.loadUrl(initialUrl, headers)
        } else {
            webView.loadUrl(initialUrl)
        }
    }

    private fun configureWebViewSettings() {
        val settings = webView.settings
        
        // Dynamic JavaScript & DOM Storage (Crucial for Progressive Web Apps)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true

        // Enable popup window handling by mobile app
        settings.setSupportMultipleWindows(true)

        // Cache mode for progressive responsiveness & offline handling
        settings.cacheMode = WebSettings.LOAD_DEFAULT

        // Responsive Viewport Controls
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.setSupportZoom(true)
        settings.builtInZoomControls = true
        settings.displayZoomControls = false

        // Security & Compatibility Config
        settings.allowFileAccess = false
        settings.allowContentAccess = true
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }

        // Enable Hardware Acceleration on view level
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
    }

    private fun setupWebViewClients() {
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                val args = mapOf("progress" to newProgress)
                methodChannel.invokeMethod("onProgressChanged", args)
                if (newProgress > 50 && isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }
            }

            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                val args = mapOf("title" to (title ?: ""))
                methodChannel.invokeMethod("onTitleReceived", args)
            }

            override fun onPermissionRequest(request: PermissionRequest?) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    request?.grant(request.resources)
                }
            }

            // Mobile app handles website popups and automatically closes them quickly if Turbo is active
            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                val popupWebView = WebView(context)
                popupWebView.settings.javaScriptEnabled = true
                popupWebView.settings.domStorageEnabled = true

                val transport = resultMsg?.obj as? WebView.WebViewTransport
                transport?.webView = popupWebView
                resultMsg?.sendToTarget()

                val delay = if (isTurboBetActive) 1000L else popupAutoCloseDelayMs
                val args = mapOf("message" to "Website popup opened. Mobile app will auto-close in ${delay / 1000}s.")
                methodChannel.invokeMethod("onPopupOpened", args)

                // Auto-close website popup after delay
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        popupWebView.stopLoading()
                        popupWebView.destroy()
                        val closeArgs = mapOf("message" to "Website popup auto-closed by mobile app.")
                        methodChannel.invokeMethod("onPopupAutoClosed", closeArgs)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, delay)

                return true
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                val args = mapOf("url" to (url ?: ""))
                methodChannel.invokeMethod("onPageStarted", args)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                
                // Inject Turbo Bet timer acceleration script
                if (isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }

                val args = mapOf("url" to (url ?: ""))
                methodChannel.invokeMethod("onPageFinished", args)
            }

            @Suppress("DEPRECATION")
            override fun onReceivedError(
                view: WebView?,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                val args = mapOf(
                    "errorCode" to errorCode,
                    "description" to (description ?: "Unknown error"),
                    "failingUrl" to (failingUrl ?: "")
                )
                methodChannel.invokeMethod("onErrorReceived", args)
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && request?.isForMainFrame == true) {
                    val args = mapOf(
                        "errorCode" to (error?.errorCode ?: -1),
                        "description" to (error?.description?.toString() ?: "Unknown error"),
                        "failingUrl" to (request.url?.toString() ?: "")
                    )
                    methodChannel.invokeMethod("onErrorReceived", args)
                }
            }

            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                if (url == null) return false
                return handleCustomUrlSchemes(url)
            }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val url = request?.url?.toString() ?: return false
                    return handleCustomUrlSchemes(url)
                }
                return false
            }
        }
    }

    private fun injectTurboBetAccelerationScript() {
        val jsScript = """
            (function() {
                if (window.__turboBetEngineInjected) return;
                window.__turboBetEngineInjected = true;
                window.__turboBetActive = ${if (isTurboBetActive) "true" else "false"};

                console.log("Turbo Bet Engine Initialized: Active = " + window.__turboBetActive);

                // Speed up native JavaScript timers when Turbo Bet is active
                const originalSetInterval = window.setInterval;
                const originalSetTimeout = window.setTimeout;

                window.setInterval = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay && delay >= 900) {
                        // Accelerate 1-second countdown intervals to 100ms (10x speed)
                        delay = Math.max(50, Math.floor(delay / 10));
                    }
                    return originalSetInterval.call(this, fn, delay, ...args);
                };

                window.setTimeout = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay && delay >= 900) {
                        // Accelerate countdown timeouts to 100ms
                        delay = Math.max(50, Math.floor(delay / 10));
                    }
                    return originalSetTimeout.call(this, fn, delay, ...args);
                };

                // Continuous DOM monitor for countdown popups & bet processing overlays
                const accelerateBetCountdowns = function() {
                    if (!window.__turboBetActive) return;

                    // Scan modal elements containing bet status or countdown numbers
                    const modalSelectors = [
                        '.popup', '.modal', '#popup', '#modal', '.overlay', '.dialog',
                        '[class*="popup"]', '[class*="modal"]', '[id*="popup"]', '[id*="modal"]',
                        '[class*="bet"]', '[class*="cashout"]', '[class*="confirm"]'
                    ];

                    modalSelectors.forEach(function(selector) {
                        document.querySelectorAll(selector).forEach(function(el) {
                            if (!el || el.offsetParent === null) return;
                            const text = (el.innerText || el.textContent || '').trim();

                            // Detect bet processing or cash out countdown popups (e.g. "5", "4", "3", "2", "1")
                            if (text.includes("being processed") || text.includes("Please wait") || text.includes("Cashout") || text.match(/\b[1-5]\b/)) {
                                // Fast-forward countdown element numbers to 0 or trigger immediate click
                                const countElems = el.querySelectorAll('span, div, p, h1, h2, h3, h4, b, strong');
                                countElems.forEach(function(c) {
                                    const val = (c.innerText || '').trim();
                                    if (/^[1-5]$/.test(val)) {
                                        c.innerText = '0';
                                    }
                                });

                                // Look for immediate confirm or place bet buttons to auto-click if needed
                                const actionBtn = el.querySelector('button.active, .btn-primary, [class*="confirm"], [class*="submit"]');
                                if (actionBtn && !actionBtn.dataset.turboClicked) {
                                    actionBtn.dataset.turboClicked = "true";
                                    setTimeout(function() { actionBtn.click(); }, 50);
                                }
                            }
                        });
                    });
                };

                setInterval(accelerateBetCountdowns, 150);

                try {
                    const observer = new MutationObserver(accelerateBetCountdowns);
                    observer.observe(document.body || document.documentElement, { childList: true, subtree: true, characterData: true });
                } catch(e) {}
            })();
        """.trimIndent()

        webView.evaluateJavascript(jsScript, null)
    }

    private fun updateTurboState(enabled: Boolean) {
        isTurboBetActive = enabled
        val jsUpdate = "window.__turboBetActive = ${if (enabled) "true" else "false"}; console.log('Turbo Bet set to ' + window.__turboBetActive);"
        webView.evaluateJavascript(jsUpdate, null)
        if (enabled) {
            injectTurboBetAccelerationScript()
        }
    }

    private fun handleCustomUrlSchemes(url: String): Boolean {
        if (url.startsWith("http://") || url.startsWith("https://")) {
            return false // Let WebView load standard web links
        }

        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            true
        }
    }

    override fun getView(): View {
        return webView
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url")
                val headers = call.argument<Map<String, String>>("headers")
                if (url != null) {
                    if (headers != null && headers.isNotEmpty()) {
                        webView.loadUrl(url, headers)
                    } else {
                        webView.loadUrl(url)
                    }
                    result.success(true)
                } else {
                    result.error("INVALID_URL", "URL parameter was null", null)
                }
            }
            "reload" -> {
                webView.reload()
                result.success(true)
            }
            "goBack" -> {
                if (webView.canGoBack()) {
                    webView.goBack()
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "goForward" -> {
                if (webView.canGoForward()) {
                    webView.goForward()
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "canGoBack" -> {
                result.success(webView.canGoBack())
            }
            "canGoForward" -> {
                result.success(webView.canGoForward())
            }
            "evaluateJavascript" -> {
                val code = call.argument<String>("code")
                if (code != null) {
                    webView.evaluateJavascript(code) { jsResult ->
                        result.success(jsResult)
                    }
                } else {
                    result.error("INVALID_CODE", "JavaScript code parameter was null", null)
                }
            }
            "clearCache" -> {
                val includeDiskFiles = call.argument<Boolean>("includeDiskFiles") ?: true
                webView.clearCache(includeDiskFiles)
                result.success(true)
            }
            "getUrl" -> {
                result.success(webView.url)
            }
            "getTitle" -> {
                result.success(webView.title)
            }
            "setPopupAutoCloseDelay" -> {
                val delayMs = call.argument<Number>("delayMs")?.toLong() ?: 1000L
                popupAutoCloseDelayMs = delayMs
                result.success(true)
            }
            "setTurboBetEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                updateTurboState(enabled)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        webView.stopLoading()
        webView.destroy()
    }
}

