# Cricket Batting - Pure Native Android Application

A high-performance **100% Pure Native Android (Kotlin)** application built for progressive web platforms with custom WebView optimization, JavaScript acceleration, and dynamic URL management.

## 🚀 Key Features

* **Pure Native Architecture**: Built completely with Kotlin, Android Jetpack, Material Design 3, ViewBinding, and Coroutines.
* **Custom Turbo WebView Engine (`NativeWebViewEngine.kt`)**:
  * **2-Second Batting Dialog Auto-Dismiss**: Detects 5-second betting processing dialogs/popups (*"your bet is being processed"*, *"cashout in progress"*, *"placing your bet"*), keeps them visible for 2 seconds with an active countdown, and automatically dismisses them.
  * **JavaScript Timer Acceleration**: Scales website 5-second timers to execute in 2 seconds.
  * **Zero-Latency AndroidBridge**: Native `@JavascriptInterface` for 2-way web-app communication.
  * **Desktop/Mobile Rendering**: Optimized Chrome Mobile user-agent, DOM storage, hardware acceleration, and third-party cookies.
  * **Multi-Window & File Chooser**: Supports popup windows within the app and camera/gallery file uploads.
* **72-Hour Session Persistence (`RemoteConfigManager.kt`)**:
  * Auto-tracks and verifies 72-hour session cycles using local `SharedPreferences`.
* **Animated Splash Screen (`SplashActivity.kt`)**:
  * Cricket Batting themed splash screen with smooth scale/fade animations and 72-hour session verification badge.
* **Full Control Bar & Navigation (`MainActivity.kt`)**:
  * Back, Forward, Refresh, Home buttons.
  * Dynamic Target URL Dialog (switch between default `https://stables365.com/` and custom URLs anytime).
  * Dark / Light Theme switching.
  * Fullscreen mode toggle.
  * Pull-to-refresh (`SwipeRefreshLayout`) and loading progress indicator.
  * Error recovery state with Retry action.

---

## 🛠️ How to Open in Android Studio

1. Open **Android Studio**.
2. Click **File > Open** and select the `android` folder (or project root).
3. Android Studio will automatically sync the Gradle files and build the project.
4. Run on an Android device or emulator (Android 5.0+ / API 21 to 34).
