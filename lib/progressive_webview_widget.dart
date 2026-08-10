import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'native_webview_controller.dart';

typedef OnWebViewCreated = void Function(NativeWebViewController controller);

class ProgressiveWebViewWidget extends StatefulWidget {
  final String initialUrl;
  final Map<String, String>? headers;
  final bool isTurboActive;
  final OnWebViewCreated? onWebViewCreated;
  final ValueChanged<int>? onProgress;
  final ValueChanged<String>? onTitleReceived;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<String>? onPageFinished;
  final ValueChanged<String>? onPopupOpened;
  final ValueChanged<String>? onPopupAutoClosed;

  const ProgressiveWebViewWidget({
    super.key,
    required this.initialUrl,
    this.headers,
    this.isTurboActive = true,
    this.onWebViewCreated,
    this.onProgress,
    this.onTitleReceived,
    this.onPageStarted,
    this.onPageFinished,
    this.onPopupOpened,
    this.onPopupAutoClosed,
  });

  @override
  State<ProgressiveWebViewWidget> createState() => _ProgressiveWebViewWidgetState();
}


class _ProgressiveWebViewWidgetState extends State<ProgressiveWebViewWidget> {
  NativeWebViewController? _controller;
  int _progress = 0;
  bool _hasError = false;
  String _errorMessage = '';
  String _failingUrl = '';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.android, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                'Native Android WebView',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Platform: ${defaultTargetPlatform.name}.\nNative WebView via MethodChannel is configured for Android devices/emulators.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    const String viewType = 'com.example.progressive_webview/native_webview';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'initialUrl': widget.initialUrl,
      if (widget.headers != null) 'headers': widget.headers,
    };

    return Stack(
      children: [
        // Main Native Android View
        if (!_hasError)
          PlatformViewLink(
            viewType: viewType,
            surfaceFactory: (context, controller) {
              return AndroidViewSurface(
                controller: controller as AndroidViewController,
                gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              );
            },
            onCreatePlatformView: (params) {
              return PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () {
                  params.onFocusChanged(true);
                },
              )..addOnPlatformViewCreatedListener((id) {
                  params.onPlatformViewCreated(id);
                  _onPlatformViewCreated(id);
                })..create();
            },
          ),

        // Responsive Offline / Error State Fallback UI
        if (_hasError)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Unable to Connect',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage.isNotEmpty
                        ? _errorMessage
                        : 'Please check your network connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  if (_failingUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _failingUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _retryLoad,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant ProgressiveWebViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTurboActive != widget.isTurboActive) {
      _controller?.setTurboBetEnabled(widget.isTurboActive);
    }
  }

  void _onPlatformViewCreated(int id) {
    final controller = NativeWebViewController(id);
    _controller = controller;

    controller.onProgressChanged = (progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
          if (progress == 100 && _hasError) {
            _hasError = false;
          }
        });
        widget.onProgress?.call(progress);
      }
    };

    controller.onTitleReceived = (title) {
      widget.onTitleReceived?.call(title);
    };

    controller.onPageStarted = (url) {
      if (mounted) {
        setState(() {
          _hasError = false;
        });
        widget.onPageStarted?.call(url);
      }
    };

    controller.onPageFinished = (url) {
      widget.onPageFinished?.call(url);
    };

    controller.onErrorReceived = (errorCode, description, failingUrl) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '$description (Error code: $errorCode)';
          _failingUrl = failingUrl;
        });
      }
    };

    controller.onPopupOpened = (msg) {
      widget.onPopupOpened?.call(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    controller.onPopupAutoClosed = (msg) {
      widget.onPopupAutoClosed?.call(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    widget.onWebViewCreated?.call(controller);
  }

  void _retryLoad() {
    setState(() {
      _hasError = false;
      _progress = 10;
    });
    if (_failingUrl.isNotEmpty) {
      _controller?.loadUrl(_failingUrl);
    } else {
      _controller?.reload();
    }
  }
}
