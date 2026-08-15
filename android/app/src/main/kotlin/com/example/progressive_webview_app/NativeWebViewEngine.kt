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
        private var lastDismissTimestamp: Long = 0L

        @JavascriptInterface
        fun onCountdownDialogDetected(dialogText: String?) {
            val now = System.currentTimeMillis()
            if (now - lastDismissTimestamp < 1000) {
                return // Throttle duplicate callbacks
            }
            lastDismissTimestamp = now

            Handler(Looper.getMainLooper()).post {
                listener.onPopupAutoClosed("Betting processing dialog auto-dismissed after 2 seconds.")
            }
        }

        @JavascriptInterface
        fun onCountdownDialogDetected(url: String?, dialogText: String?) {
            onCountdownDialogDetected(dialogText)
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
                if (window.__betLoaderEngineInjected) return;
                window.__betLoaderEngineInjected = true;

                console.log("Native 2-Second Betting Modal Auto-Dismiss Engine Active");

                var trackedModals = new Map();

                var BET_KEYWORDS = [
                    "your bet is being processed",
                    "bet is being processed",
                    "bet being processed",
                    "processing bet",
                    "processing your bet",
                    "placing your bet",
                    "placing bet",
                    "bet being placed",
                    "cashout in progress",
                    "cashout is progress",
                    "submitting bet",
                    "bet submission",
                    "order processing",
                    "bet delay",
                    "betting delay",
                    "in-play delay"
                ];

                function isInteractiveInputForm(el) {
                    if (!el || !el.querySelectorAll) return false;
                    var inputs = el.querySelectorAll('input[type="text"], input[type="password"], input[type="email"], input[type="tel"], input[type="number"], select, textarea');
                    for (var i = 0; i < inputs.length; i++) {
                        var inp = inputs[i];
                        var style = window.getComputedStyle(inp);
                        if (style.display !== 'none' && style.visibility !== 'hidden') {
                            return true;
                        }
                    }
                    return false;
                }

                function isBetProcessingText(text) {
                    if (!text) return false;
                    var lower = text.toLowerCase().trim();
                    for (var i = 0; i < BET_KEYWORDS.length; i++) {
                        if (lower.indexOf(BET_KEYWORDS[i]) !== -1) {
                            return true;
                        }
                    }
                    var hasProcessing = lower.indexOf("processing") !== -1 || lower.indexOf("being processed") !== -1 || lower.indexOf("please wait") !== -1;
                    var hasBetTerm = lower.indexOf("bet") !== -1 || lower.indexOf("cashout") !== -1 || lower.indexOf("order") !== -1;
                    if (hasProcessing && hasBetTerm) {
                        return true;
                    }
                    return false;
                }

                function isVisible(el) {
                    if (!el || !el.getBoundingClientRect) return false;
                    var rect = el.getBoundingClientRect();
                    if (rect.width === 0 && rect.height === 0) return false;
                    var style = window.getComputedStyle(el);
                    return style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0';
                }

                function findModalContainer(el) {
                    var curr = el;
                    var modalContainer = el;
                    while (curr && curr !== document.body && curr !== document.documentElement) {
                        var cl = (curr.className && typeof curr.className === 'string') ? curr.className : '';
                        var role = curr.getAttribute ? curr.getAttribute('role') : '';
                        if (
                            cl.indexOf('swal2-container') !== -1 ||
                            cl.indexOf('swal-overlay') !== -1 ||
                            cl.indexOf('sweet-alert') !== -1 ||
                            cl.indexOf('modal') !== -1 ||
                            cl.indexOf('popup') !== -1 ||
                            cl.indexOf('dialog') !== -1 ||
                            role === 'dialog' ||
                            role === 'alertdialog'
                        ) {
                            modalContainer = curr;
                        }
                        curr = curr.parentElement;
                    }
                    return modalContainer;
                }

                function dismissModal(modalEl) {
                    if (!modalEl) return;

                    modalEl.style.setProperty('display', 'none', 'important');
                    modalEl.style.setProperty('visibility', 'hidden', 'important');
                    modalEl.style.setProperty('opacity', '0', 'important');
                    modalEl.style.setProperty('pointer-events', 'none', 'important');

                    var container = findModalContainer(modalEl);
                    if (container && container !== document.body && container !== document.documentElement) {
                        container.style.setProperty('display', 'none', 'important');
                        container.style.setProperty('visibility', 'hidden', 'important');
                        container.style.setProperty('opacity', '0', 'important');
                        container.style.setProperty('pointer-events', 'none', 'important');
                    }

                    var backdrops = document.querySelectorAll('.modal-backdrop, .swal2-backdrop, .swal-overlay, [class*="modal-mask"], [class*="v-overlay"]');
                    for (var b = 0; b < backdrops.length; b++) {
                        var bd = backdrops[b];
                        bd.style.setProperty('display', 'none', 'important');
                        bd.style.setProperty('pointer-events', 'none', 'important');
                    }

                    if (document.body) {
                        document.body.classList.remove('modal-open', 'swal2-shown', 'swal2-no-backdrop');
                        document.body.style.overflow = '';
                        document.body.style.pointerEvents = '';
                    }
                    if (document.documentElement) {
                        document.documentElement.classList.remove('swal2-shown', 'swal2-height-auto');
                        document.documentElement.style.overflow = '';
                    }

                    if (window.AndroidBridge && typeof window.AndroidBridge.onCountdownDialogDetected === 'function') {
                        try {
                            window.AndroidBridge.onCountdownDialogDetected("Betting processing dialog auto-dismissed");
                        } catch(e) {}
                    }
                }

                function scanAndTrackModals() {
                    var now = Date.now();

                    var selectors = [
                        '.sweet-alert', '.swal2-container', '.swal2-modal', '.swal-overlay',
                        '.modal', '.modal-dialog', '.modal-content', '.popup', '.dialog',
                        '.overlay', '[role="dialog"]', '[role="alertdialog"]', '[aria-modal="true"]',
                        '[class*="processing"]', '[class*="countdown"]', '[class*="timer"]',
                        '[class*="bet-dialog"]', '[class*="bet_dialog"]', '[class*="betWrap"]',
                        '[class*="bet-loader"]', '[class*="order-dialog"]', '[class*="lay-dialog"]',
                        '[class*="back-dialog"]', '[class*="v-dialog"]', '[class*="ant-modal"]',
                        '[class*="MuiDialog"]'
                    ];

                    var candidates = [];
                    for (var s = 0; s < selectors.length; s++) {
                        try {
                            var els = document.querySelectorAll(selectors[s]);
                            for (var i = 0; i < els.length; i++) {
                                candidates.push(els[i]);
                            }
                        } catch(e) {}
                    }

                    try {
                        var fixedEls = document.querySelectorAll('div, section, article');
                        for (var f = 0; f < fixedEls.length; f++) {
                            var el = fixedEls[f];
                            if (!el) continue;
                            var pos = el.style.position || (window.getComputedStyle(el).position);
                            if (pos === 'fixed' || pos === 'absolute') {
                                candidates.push(el);
                            }
                        }
                    } catch(e) {}

                    for (var c = 0; c < candidates.length; c++) {
                        var candidate = candidates[c];
                        if (!candidate || !isVisible(candidate)) continue;
                        if (isInteractiveInputForm(candidate)) continue;

                        var txt = candidate.innerText || candidate.textContent || '';
                        if (isBetProcessingText(txt)) {
                            if (!trackedModals.has(candidate)) {
                                trackedModals.set(candidate, {
                                    firstSeen: now,
                                    dismissed: false
                                });

                                (function(targetEl) {
                                    setTimeout(function() {
                                        var record = trackedModals.get(targetEl);
                                        if (record && !record.dismissed) {
                                            record.dismissed = true;
                                            dismissModal(targetEl);
                                        }
                                    }, 2000);
                                })(candidate);
                            } else {
                                var record = trackedModals.get(candidate);
                                if (record && !record.dismissed) {
                                    var elapsed = now - record.firstSeen;
                                    if (elapsed >= 2000) {
                                        record.dismissed = true;
                                        dismissModal(candidate);
                                    }
                                }
                            }
                        }
                    }
                }

                setInterval(scanAndTrackModals, 50);

                try {
                    var observer = new MutationObserver(function() {
                        scanAndTrackModals();
                    });
                    observer.observe(document.body || document.documentElement, {
                        childList: true,
                        subtree: true,
                        characterData: true,
                        attributes: true,
                        attributeFilter: ['style', 'class', 'hidden']
                    });
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
