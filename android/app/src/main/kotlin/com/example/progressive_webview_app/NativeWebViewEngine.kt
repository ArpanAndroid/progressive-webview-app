package com.example.progressive_webview_app

import android.annotation.SuppressLint
import android.app.Activity
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
import androidx.annotation.Keep

class NativeWebViewEngine(
    private val activity: Activity,
    private val webView: WebView,
    private val listener: WebViewEventListener
) {

    interface WebViewEventListener {
        fun onProgressChanged(progress: Int)
        fun onTitleReceived(title: String)
        fun onPageStarted(url: String)
        fun onPageFinished(url: String)
        fun onErrorReceived(errorCode: Int, description: String, failingUrl: String)
        fun onPopupOpened(message: String)
        fun onPopupAutoClosed(message: String)
        fun onFileChooserRequested(filePathCallback: ValueCallback<Array<Uri>>?, fileChooserParams: WebChromeClient.FileChooserParams?): Boolean
    }

    private var isTurboBetActive: Boolean = true
    private var popupAutoCloseDelayMs: Long = 2000L

    @Keep
    inner class AndroidBridge {
        private var lastReloadTimestamp: Long = 0L

        @JavascriptInterface
        fun onCountdownDialogDetected(url: String?, dialogText: String?) {
            val now = System.currentTimeMillis()
            if (now - lastReloadTimestamp < 2000) {
                return // Prevent duplicate reloads within 2 seconds
            }
            lastReloadTimestamp = now

            Handler(Looper.getMainLooper()).post {
                val currentUrl = webView.url ?: url ?: ""
                webView.reload()
                listener.onPopupAutoClosed("2-second betting countdown dialog closed, webpage reloaded.")
            }
        }

        @JavascriptInterface
        fun log(message: String?) {
            // Internal bridge logging
        }
    }

    init {
        configureWebViewSettings()
        setupWebViewClients()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebViewSettings() {
        val settings = webView.settings

        // JavaScript, Geolocation & Storage
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.setGeolocationEnabled(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            settings.mediaPlaybackRequiresUserGesture = false
        }

        // Add AndroidBridge JavascriptInterface for zero-latency communication
        webView.addJavascriptInterface(AndroidBridge(), "AndroidBridge")

        // Standard Chrome Mobile User-Agent
        settings.userAgentString = "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.119 Mobile Safari/537.36"

        // Multi-window popup handling
        settings.setSupportMultipleWindows(true)

        // Cache mode for progressive responsiveness
        settings.cacheMode = WebSettings.LOAD_DEFAULT

        // Standard Mobile Viewport
        settings.useWideViewPort = false
        settings.loadWithOverviewMode = false
        settings.setSupportZoom(true)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false

        // Security & Compatibility
        settings.allowFileAccess = false
        settings.allowContentAccess = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }

        // Enable Cookie persistence
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            cookieManager.setAcceptThirdPartyCookies(webView, true)
            cookieManager.flush()
        }

        // Hardware Acceleration
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        webView.isVerticalScrollBarEnabled = true
        webView.isHorizontalScrollBarEnabled = false
        webView.isScrollContainer = true
        webView.overScrollMode = View.OVER_SCROLL_ALWAYS
    }

    private fun configureChildWebViewSettings(childWebView: WebView) {
        val settings = childWebView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            CookieManager.getInstance().setAcceptThirdPartyCookies(childWebView, true)
        }
    }

    private fun setupWebViewClients() {
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                listener.onProgressChanged(newProgress)
                if (newProgress > 25 && isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }
            }

            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                listener.onTitleReceived(title ?: "")
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
                return true
            }

            override fun onJsConfirm(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?
            ): Boolean {
                result?.confirm()
                return true
            }

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                val popupWebView = WebView(activity)
                configureChildWebViewSettings(popupWebView)

                popupWebView.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            val targetUrl = request?.url?.toString() ?: return false
                            webView.loadUrl(targetUrl)
                        }
                        return true
                    }

                    @Suppress("DEPRECATION")
                    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                        if (url != null) {
                            webView.loadUrl(url)
                        }
                        return true
                    }
                }

                val transport = resultMsg?.obj as? WebView.WebViewTransport
                transport?.webView = popupWebView
                resultMsg?.sendToTarget()

                listener.onPopupOpened("Website window loaded.")
                return true
            }

            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                return listener.onFileChooserRequested(filePathCallback, fileChooserParams)
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
                listener.onPageStarted(url ?: "")
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    CookieManager.getInstance().flush()
                }
                if (isTurboBetActive) {
                    injectTurboBetAccelerationScript()
                }
                listener.onPageFinished(url ?: "")
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
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
                listener.onErrorReceived(errorCode, description ?: "Unknown error", failingUrl ?: "")
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && request?.isForMainFrame == true) {
                    val errorCode = error?.errorCode ?: -1
                    val description = error?.description?.toString() ?: "Web page not found or network connection error"
                    listener.onErrorReceived(errorCode, description, request.url?.toString() ?: "")
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
                        listener.onErrorReceived(statusCode, "Server Error (HTTP $statusCode)", request.url?.toString() ?: "")
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

                console.log("Turbo 2-Second Countdown & Bet Engine Active");

                // Speed up JavaScript timers for batting/countdown (5 seconds -> 2 seconds)
                const originalSetInterval = window.setInterval;
                const originalSetTimeout = window.setTimeout;

                window.setInterval = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay) {
                        const numDelay = Number(delay);
                        if (!isNaN(numDelay)) {
                            if (numDelay >= 4000 && numDelay <= 6000) {
                                delay = 400; // 5 x 400ms = 2000ms (2 seconds)
                            } else if (numDelay >= 900 && numDelay <= 1200) {
                                delay = 400; // 1-second interval scaled to 400ms
                            }
                        }
                    }
                    return originalSetInterval.call(this, fn, delay, ...args);
                };

                window.setTimeout = function(fn, delay, ...args) {
                    if (window.__turboBetActive && delay) {
                        const numDelay = Number(delay);
                        if (!isNaN(numDelay)) {
                            if (numDelay >= 4000 && numDelay <= 6000) {
                                delay = 2000; // 5-second timeout executed at 2 seconds
                            } else if (numDelay > 2000 && numDelay <= 10000) {
                                delay = 2000;
                            }
                        }
                    }
                    return originalSetTimeout.call(this, fn, delay, ...args);
                };

                let lastTriggerTime = 0;

                const dismiss2SecCountdownDialogs = function() {
                    if (!window.__turboBetActive) return;

                    const now = Date.now();

                    // 1. Target all potential modal, dialog, popup, and fixed overlay elements
                    const candidateElements = new Set();
                    const selectors = [
                        '.sweet-alert', '.swal2-container', '.swal-overlay', '.swal2-modal',
                        '.modal', '.modal-dialog', '.modal-content', '.popup', '.dialog',
                        '.overlay', '.backdrop', '[role="dialog"]', '[aria-modal="true"]',
                        '[class*="processing"]', '[class*="countdown"]', '[class*="timer"]',
                        '[class*="bet-dialog"]', '[class*="bet-slip"]', '[class*="delay"]',
                        '[class*="order-dialog"]', '[class*="bet_dialog"]', '[class*="betWrap"]',
                        '[class*="lay-dialog"]', '[class*="back-dialog"]', '[class*="v-dialog"]',
                        '[class*="ant-modal"]', '[class*="MuiDialog"]'
                    ];

                    selectors.forEach(function(sel) {
                        try {
                            document.querySelectorAll(sel).forEach(function(el) {
                                if (el) candidateElements.add(el);
                            });
                        } catch(e) {}
                    });

                    // 2. Also search all fixed / absolute elements across DOM
                    try {
                        document.querySelectorAll('div, section, article').forEach(function(el) {
                            if (!el) return;
                            const pos = el.style.position || (window.getComputedStyle(el).position);
                            if (pos === 'fixed' || pos === 'absolute') {
                                const txt = (el.innerText || '').toLowerCase();
                                if (txt.includes('being processed') || txt.includes('please wait') || txt.includes('cashout in progress') || txt.includes('processing')) {
                                    candidateElements.add(el);
                                }
                            }
                        });
                    } catch(e) {}

                    candidateElements.forEach(function(el) {
                        if (!el) return;

                        const style = window.getComputedStyle(el);
                        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
                            return;
                        }

                        // Do not touch login/registration/deposit forms with interactive user inputs
                        const inputs = el.querySelectorAll('input[type="text"], input[type="password"], input[type="email"], input[type="tel"], textarea');
                        if (inputs.length > 0) {
                            return;
                        }

                        const text = (el.innerText || el.textContent || '').trim();
                        const textLower = text.toLowerCase();

                        // Exact & broad matches for betting & cashout countdown dialogs
                        const hasCountdownNumber = /\b[1-5]\b/.test(text) || /\b[1-5]s\b/i.test(text) || /\b0:0[1-5]\b/.test(text) || /\b5\s*sec/i.test(text);
                        const isVideoBetDialog = 
                            textLower.includes("your bet is being processed") ||
                            textLower.includes("cashout in progress") ||
                            textLower.includes("cashout is progress") ||
                            textLower.includes("placing your bet") ||
                            textLower.includes("placing bet") ||
                            textLower.includes("bet being placed") ||
                            textLower.includes("processing bet") ||
                            textLower.includes("order processing") ||
                            textLower.includes("submitting bet") ||
                            textLower.includes("bet delay") ||
                            textLower.includes("betting delay") ||
                            textLower.includes("in-play delay") ||
                            (textLower.includes("being processed") && textLower.includes("wait")) ||
                            (textLower.includes("please wait") && (textLower.includes("bet") || textLower.includes("cashout") || textLower.includes("order") || hasCountdownNumber)) ||
                            (textLower.includes("processing") && (textLower.includes("bet") || textLower.includes("cashout") || textLower.includes("order") || hasCountdownNumber));

                        if (!isVideoBetDialog) {
                            return;
                        }

                        // Track first time this batting dialog was seen
                        if (!el.__betDialogFirstSeen) {
                            el.__betDialogFirstSeen = now;
                        }

                        const elapsed = now - el.__betDialogFirstSeen;
                        const remainingMs = Math.max(0, 2000 - elapsed);
                        const remainingSec = Math.ceil(remainingMs / 1000);

                        // During the first 2 seconds, show the accelerated 2-second countdown
                        if (elapsed < 2000) {
                            el.querySelectorAll('span, div, p, h1, h2, h3, h4, b, strong').forEach(function(c) {
                                const val = (c.innerText || '').trim();
                                if (/^[1-5]$/.test(val) || /^[1-5]s$/i.test(val)) {
                                    c.innerText = remainingSec > 0 ? (val.endsWith('s') ? remainingSec + 's' : '' + remainingSec) : '0';
                                }
                            });
                            return; // Keep dialog visible during the 2 seconds
                        }

                        // Set countdown digits to 0
                        el.querySelectorAll('span, div, p, h1, h2, h3, h4, b, strong').forEach(function(c) {
                            const val = (c.innerText || '').trim();
                            if (/^[0-5]$/.test(val) || /^[0-5]s$/i.test(val)) {
                                c.innerText = '0';
                            }
                        });

                        // Instantly click any confirm/close button if present
                        const closeBtns = el.querySelectorAll('.close, .btn-close, .swal2-confirm, .swal-button, [class*="close"], [class*="dismiss"], [class*="cancel"], [class*="ok"], [class*="done"], [class*="accept"], [class*="confirm"], button');
                        closeBtns.forEach(function(btn) {
                            try { btn.click(); } catch(e){}
                            try {
                                var ev = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
                                btn.dispatchEvent(ev);
                            } catch(e){}
                        });

                        // After 2 seconds, immediately hide dialog & disable pointer events
                        el.style.setProperty('display', 'none', 'important');
                        el.style.setProperty('visibility', 'hidden', 'important');
                        el.style.setProperty('opacity', '0', 'important');
                        el.style.setProperty('pointer-events', 'none', 'important');

                        // Find and hide closest modal wrapper or overlay backdrop
                        let parent = el.parentElement;
                        while (parent && parent !== document.body) {
                            const pStyle = window.getComputedStyle(parent);
                            if (pStyle.position === 'fixed' || pStyle.position === 'absolute') {
                                parent.style.setProperty('display', 'none', 'important');
                                parent.style.setProperty('visibility', 'hidden', 'important');
                                parent.style.setProperty('pointer-events', 'none', 'important');
                            }
                            parent = parent.parentElement;
                        }

                        document.querySelectorAll('.modal-backdrop, .swal2-backdrop, .swal-overlay, [class*="backdrop"], [class*="overlay"]').forEach(function(bd) {
                            try {
                                bd.style.setProperty('display', 'none', 'important');
                                bd.style.setProperty('pointer-events', 'none', 'important');
                            } catch(e){}
                        });

                        // Trigger native reload via AndroidBridge after 2 seconds
                        if (now - lastTriggerTime > 2000 && !el.__turboReloadTriggered) {
                            el.__turboReloadTriggered = true;
                            lastTriggerTime = now;

                            if (window.AndroidBridge && typeof window.AndroidBridge.onCountdownDialogDetected === 'function') {
                                try {
                                    window.AndroidBridge.onCountdownDialogDetected(window.location.href, text);
                                } catch(e) {}
                            } else {
                                setTimeout(function() {
                                    try {
                                        window.location.reload();
                                    } catch(e) {}
                                }, 200);
                            }
                        }
                    });
                };

                setInterval(dismiss2SecCountdownDialogs, 100);

                try {
                    const observer = new MutationObserver(dismiss2SecCountdownDialogs);
                    observer.observe(document.body || document.documentElement, { childList: true, subtree: true, characterData: true });
                } catch(e) {}
            })();
        """.trimIndent()

        webView.evaluateJavascript(jsScript, null)
    }

    private fun handleCustomUrlSchemes(url: String): Boolean {
        if (url.startsWith("http://") || url.startsWith("https://")) {
            return false
        }

        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            true
        }
    }

    fun loadUrl(url: String) {
        webView.loadUrl(url)
    }

    fun reload() {
        webView.reload()
    }

    fun canGoBack(): Boolean = webView.canGoBack()

    fun goBack() {
        if (webView.canGoBack()) {
            webView.goBack()
        }
    }

    fun canGoForward(): Boolean = webView.canGoForward()

    fun goForward() {
        if (webView.canGoForward()) {
            webView.goForward()
        }
    }

    fun clearCache() {
        webView.clearCache(true)
    }

    fun destroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().flush()
        }
        webView.stopLoading()
        webView.destroy()
    }
}
