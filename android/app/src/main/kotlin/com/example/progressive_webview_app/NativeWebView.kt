package com.example.progressive_webview_app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
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
    private var popupAutoCloseDelayMs: Long = 2000L // 2-second auto-close delay for dialogs/popups
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
        
        // Dynamic JavaScript, Geolocation & DOM Storage (Crucial for Progressive Web Apps)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.setGeolocationEnabled(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            settings.mediaPlaybackRequiresUserGesture = false
        }

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

        // Enable Cookie persistence across sessions & background restarts
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            cookieManager.setAcceptThirdPartyCookies(webView, true)
            cookieManager.flush()
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
                if (newProgress > 10 && isTurboBetActive) {
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

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?
            ) {
                callback?.invoke(origin, true, false)
            }

            override fun onJsAlert(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?
            ): Boolean {
                result?.confirm()
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        webView.reload()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, popupAutoCloseDelayMs)
                return true
            }

            override fun onJsConfirm(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?
            ): Boolean {
                result?.confirm()
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        webView.reload()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, popupAutoCloseDelayMs)
                return true
            }

            // Mobile app handles website popups and auto-dismisses non-auth dialogs after 2 seconds
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

                val args = mapOf("message" to "Website window opened.")
                methodChannel.invokeMethod("onPopupOpened", args)

                // Auto-dismiss popup window after 2 seconds (2000ms) and reload website
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        popupWebView.stopLoading()
                        popupWebView.destroy()
                        webView.reload()
                        val argsAuto = mapOf("message" to "Website 5 sec dialog auto-dismissed after 2s & website reloaded.")
                        methodChannel.invokeMethod("onPopupAutoClosed", argsAuto)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, popupAutoCloseDelayMs)

                return true
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    CookieManager.getInstance().flush()
                }
                if (isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }
                val args = mapOf("url" to (url ?: ""))
                methodChannel.invokeMethod("onPageStarted", args)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    CookieManager.getInstance().flush()
                }
                
                if (isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }

                val args = mapOf("url" to (url ?: ""))
                methodChannel.invokeMethod("onPageFinished", args)
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                // Prevent app breakage/hanging on SSL certificate updates
                handler?.proceed()
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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && request?.isForMainFrame == true) {
                    val args = mapOf(
                        "errorCode" to (error?.errorCode ?: -1),
                        "description" to (error?.description?.toString() ?: "Web page not found or network connection error"),
                        "failingUrl" to (request.url?.toString() ?: "")
                    )
                    methodChannel.invokeMethod("onErrorReceived", args)
                }
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                errorResponse: WebResourceResponse?
            ) {
                super.onReceivedHttpError(view, request, errorResponse)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && request?.isForMainFrame == true) {
                    val statusCode = errorResponse?.statusCode ?: -1
                    if (statusCode >= 400) {
                        val args = mapOf(
                            "errorCode" to statusCode,
                            "description" to "Server Error / Web Page Not Found (HTTP $statusCode)",
                            "failingUrl" to (request.url?.toString() ?: "")
                        )
                        methodChannel.invokeMethod("onErrorReceived", args)
                    }
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
                window.__turboBetActive = ${if (isTurboBetActive) "true" else "false"};
                if (window.__turboBetEngineInjected) return;
                window.__turboBetEngineInjected = true;

                console.log("Turbo Bet Engine & 2-Sec Dialog Dismissal Active");

                // Speed up short JavaScript timers & force 5-sec dialog auto-close timeouts to 2 seconds
                const originalSetInterval = window.setInterval;
                const originalSetTimeout = window.setTimeout;

                window.setInterval = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay && typeof delay === 'number') {
                        if (delay >= 4000 && delay <= 6000) {
                            // Accelerate 5-second countdown intervals to 400ms per tick (5 ticks = 2s total)
                            delay = 400;
                        } else if (delay >= 900 && delay <= 10000) {
                            // Speed up 1 to 10 second countdown timers by 2.5x
                            delay = Math.max(100, Math.floor(delay / 2.5));
                        }
                    }
                    return originalSetInterval.call(this, fn, delay, ...args);
                };

                window.setTimeout = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay && typeof delay === 'number') {
                        if (delay >= 4000 && delay <= 6000) {
                            // Force 5-second dialog/popup dismissal timeouts to fire at 2000ms (2 seconds)
                            delay = 2000;
                        } else if (delay > 2000 && delay <= 10000) {
                            // Cap any long status modal/dialog delay (> 2s up to 10s) at 2000ms
                            delay = 2000;
                        }
                    }
                    return originalSetTimeout.call(this, fn, delay, ...args);
                };

                // Continuous DOM monitor: enforce auto-dismissal after 2 seconds (2000ms) strictly for website 5-second countdown & bet processing dialogs
                const dismiss5SecCountdownDialogs = function() {
                    if (!window.__turboBetActive) return;

                    const modalSelectors = [
                        '.popup', '.modal', '#popup', '#modal', '.overlay', '.dialog', '.toast', '.alert',
                        '.sweet-alert', '.swal2-container', '.swal-overlay', '.toast-container', '.v-dialog',
                        '.element-dialog', '.MuiDialog-root', '.ant-modal', '[role="dialog"]', '[role="alertdialog"]',
                        '[class*="popup"]', '[class*="modal"]', '[id*="popup"]', '[id*="modal"]',
                        '[class*="overlay"]', '[class*="dialog"]', '[class*="toast"]', '[class*="alert"]',
                        '[class*="bet"]', '[class*="cashout"]', '[class*="confirm"]', '[class*="success"]',
                        '[class*="placed"]', '[class*="notice"]', '[class*="msg"]', '[class*="message"]',
                        '[class*="status"]', '[class*="snack"]', '[class*="notification"]', '[class*="receipt"]',
                        '[class*="slip"]', '[class*="banner"]', '[class*="loader"]', '[class*="processing"]',
                        'div[style*="fixed"]', 'div[style*="absolute"]'
                    ];

                    const now = Date.now();

                    modalSelectors.forEach(function(selector) {
                        document.querySelectorAll(selector).forEach(function(el) {
                            if (!el) return;

                            // Check visibility
                            const style = window.getComputedStyle(el);
                            if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0' || el.offsetParent === null) {
                                delete el.__5secCountdownFirstSeen;
                                return;
                            }

                            const text = (el.innerText || el.textContent || '').trim();
                            const textLower = text.toLowerCase();

                            // Explicitly skip login/authentication, registration, deposit, password, settings or profile popups
                            if (textLower.includes("login") || textLower.includes("sign in") || textLower.includes("password") || 
                                textLower.includes("register") || textLower.includes("auth") || textLower.includes("captcha") ||
                                textLower.includes("username") || textLower.includes("otp") || textLower.includes("deposit") ||
                                textLower.includes("withdraw") || textLower.includes("wallet") || textLower.includes("profile") ||
                                textLower.includes("settings") || textLower.includes("account") || textLower.includes("help")) {
                                return;
                            }

                            // Universal detection for website 5-second countdown & bet placement/processing dialogs
                            const has5SecCountdownNumber = /\b[1-5]\b/.test(text);
                            const isBetProcessingDialog = 
                                textLower.includes("bet") || 
                                textLower.includes("being processed") || 
                                textLower.includes("processing") || 
                                textLower.includes("please wait") || 
                                textLower.includes("processing bet") || 
                                textLower.includes("bet placed") || 
                                textLower.includes("bet accepted") || 
                                textLower.includes("submitted") || 
                                textLower.includes("pending") || 
                                textLower.includes("stake") || 
                                textLower.includes("odds") || 
                                textLower.includes("matched") || 
                                textLower.includes("cashout") || 
                                textLower.includes("success") || 
                                textLower.includes("done") || 
                                textLower.includes("confirm");

                            if (has5SecCountdownNumber || isBetProcessingDialog) {
                                // Track when this 5-second countdown dialog first appeared
                                if (!el.__5secCountdownFirstSeen) {
                                    el.__5secCountdownFirstSeen = now;
                                }

                                // Fast-forward countdown element numbers (5, 4, 3, 2, 1 -> 0)
                                const countElems = el.querySelectorAll('span, div, p, h1, h2, h3, h4, b, strong');
                                countElems.forEach(function(c) {
                                    const val = (c.innerText || '').trim();
                                    if (/^[1-5]$/.test(val)) {
                                        c.innerText = '0';
                                    }
                                });

                                // Look for immediate action buttons (e.g. auto-confirm)
                                const actionBtn = el.querySelector('button.active, .btn-primary, [class*="confirm"], [class*="submit"]');
                                if (actionBtn && !actionBtn.dataset.turboClicked) {
                                    actionBtn.dataset.turboClicked = "true";
                                    setTimeout(function() { try { actionBtn.click(); } catch(e){} }, 50);
                                }

                                // DISMISS ONLY AFTER 2 SECONDS (2000ms) FOR 5-SEC COUNTDOWN DIALOG
                                if (now - el.__5secCountdownFirstSeen >= 2000) {
                                    // 1. Try to click close / ok / dismiss button if available
                                    const closeBtn = el.querySelector('.close, .btn-close, [class*="close"], [class*="dismiss"], [class*="cancel"], [class*="ok"], [class*="done"], [class*="accept"], button');
                                    if (closeBtn && !closeBtn.dataset.turboDismissed) {
                                        closeBtn.dataset.turboDismissed = "true";
                                        try { closeBtn.click(); } catch(e){}
                                    }

                                    // 2. Direct DOM dismiss/hide to guarantee disappearance after 2 sec
                                    el.style.setProperty('display', 'none', 'important');
                                    el.style.setProperty('visibility', 'hidden', 'important');
                                    el.style.setProperty('opacity', '0', 'important');
                                    el.style.setProperty('pointer-events', 'none', 'important');

                                    // 3. Automatically reload website after 5-sec countdown dialog auto-closes at 2s
                                    if (!el.__turboReloadTriggered) {
                                        el.__turboReloadTriggered = true;
                                        setTimeout(function() {
                                            try {
                                                window.location.reload();
                                            } catch(e) {}
                                        }, 200);
                                    }
                                }
                            }
                        });
                    });
                };

                setInterval(dismiss5SecCountdownDialogs, 100);

                try {
                    const observer = new MutationObserver(dismiss5SecCountdownDialogs);
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
                val clearCache = call.argument<Boolean>("clearCache") ?: true
                if (url != null) {
                    if (clearCache) {
                        try {
                            webView.clearCache(true)
                            WebStorage.getInstance().deleteAllData()
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
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
                val delayMs = call.argument<Number>("delayMs")?.toLong() ?: 2000L
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().flush()
        }
        webView.stopLoading()
        webView.destroy()
    }
}

