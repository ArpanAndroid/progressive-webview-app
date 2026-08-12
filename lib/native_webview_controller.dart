import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OnProgressChanged = void Function(int progress);
typedef OnPageStarted = void Function(String url);
typedef OnPageFinished = void Function(String url);
typedef OnErrorReceived = void Function(int errorCode, String description, String failingUrl);
typedef OnTitleReceived = void Function(String title);
typedef OnPopupOpened = void Function(String message);
typedef OnPopupAutoClosed = void Function(String message);

class NativeWebViewController {
  final int viewId;
  late final MethodChannel _channel;

  OnProgressChanged? onProgressChanged;
  OnPageStarted? onPageStarted;
  OnPageFinished? onPageFinished;
  OnErrorReceived? onErrorReceived;
  OnTitleReceived? onTitleReceived;
  OnPopupOpened? onPopupOpened;
  OnPopupAutoClosed? onPopupAutoClosed;

  NativeWebViewController(this.viewId) {
    _channel = MethodChannel('com.example.progressive_webview/native_webview_$viewId');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onProgressChanged':
        final int progress = (call.arguments as Map)['progress'] as int;
        onProgressChanged?.call(progress);
        break;
      case 'onPageStarted':
        final String url = (call.arguments as Map)['url'] as String;
        onPageStarted?.call(url);
        break;
      case 'onPageFinished':
        final String url = (call.arguments as Map)['url'] as String;
        onPageFinished?.call(url);
        break;
      case 'onErrorReceived':
        final map = call.arguments as Map;
        final int errorCode = map['errorCode'] as int;
        final String description = map['description'] as String;
        final String failingUrl = map['failingUrl'] as String;
        onErrorReceived?.call(errorCode, description, failingUrl);
        break;
      case 'onTitleReceived':
        final String title = (call.arguments as Map)['title'] as String;
        onTitleReceived?.call(title);
        break;
      case 'onPopupOpened':
        final String msg = (call.arguments as Map)['message'] as String;
        onPopupOpened?.call(msg);
        break;
      case 'onPopupAutoClosed':
        final String msg = (call.arguments as Map)['message'] as String;
        onPopupAutoClosed?.call(msg);
        break;
      default:
        if (kDebugMode) {
          print('Unrecognized method call from NativeWebView: ${call.method}');
        }
    }
  }

  Future<bool> loadUrl(String url, {Map<String, String>? headers, bool clearCache = true}) async {
    try {
      final result = await _channel.invokeMethod<bool>('loadUrl', {
        'url': url,
        'clearCache': clearCache,
        if (headers != null) 'headers': headers,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) print('Error loading URL: $e');
      return false;
    }
  }

  Future<bool> reload() async {
    try {
      final result = await _channel.invokeMethod<bool>('reload');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> goBack() async {
    try {
      final result = await _channel.invokeMethod<bool>('goBack');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> goForward() async {
    try {
      final result = await _channel.invokeMethod<bool>('goForward');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canGoBack() async {
    try {
      final result = await _channel.invokeMethod<bool>('canGoBack');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canGoForward() async {
    try {
      final result = await _channel.invokeMethod<bool>('canGoForward');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> evaluateJavascript(String code) async {
    try {
      final result = await _channel.invokeMethod<String>('evaluateJavascript', {
        'code': code,
      });
      return result;
    } catch (e) {
      if (kDebugMode) print('Error evaluating JS: $e');
      return null;
    }
  }

  Future<bool> clearCache({bool includeDiskFiles = true}) async {
    try {
      final result = await _channel.invokeMethod<bool>('clearCache', {
        'includeDiskFiles': includeDiskFiles,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setPopupAutoCloseDelay(int delayMs) async {
    try {
      final result = await _channel.invokeMethod<bool>('setPopupAutoCloseDelay', {
        'delayMs': delayMs,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUrl() async {
    try {
      return await _channel.invokeMethod<String>('getUrl');
    } catch (e) {
      return null;
    }
  }

  Future<String?> getTitle() async {
    try {
      return await _channel.invokeMethod<String>('getTitle');
    } catch (e) {
      return null;
    }
  }

  Future<bool> setTurboBetEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTurboBetEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}

