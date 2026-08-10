package com.example.progressive_webview_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.example.progressive_webview/native_webview",
                NativeWebViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
    }
}
