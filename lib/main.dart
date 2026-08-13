import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_webview_controller.dart';
import 'progressive_webview_widget.dart';
import 'remote_config_service.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProgressiveWebViewApp());
}

class ProgressiveWebViewApp extends StatefulWidget {
  const ProgressiveWebViewApp({super.key});

  @override
  State<ProgressiveWebViewApp> createState() => _ProgressiveWebViewAppState();
}

class _ProgressiveWebViewAppState extends State<ProgressiveWebViewApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _initialUrl = 'https://stables365.com/';
  bool _isLoadingInit = true;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final url = await RemoteConfigService.getTargetUrl();
    if (mounted) {
      setState(() {
        _initialUrl = url;
        _isLoadingInit = false;
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _updateUrl(String newUrl) {
    setState(() {
      _initialUrl = newUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInit) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
            ),
          ),
        ),
      );
    }

    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onSplashComplete: () {
            if (mounted) {
              setState(() {
                _showSplash = false;
              });
            }
          },
        ),
      );
    }

    return MaterialApp(
      title: 'Progressive App',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFA8B4C0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: HomeScreen(
        initialUrl: _initialUrl,
        onToggleTheme: _toggleTheme,
        onUrlChanged: _updateUrl,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String initialUrl;
  final VoidCallback onToggleTheme;
  final ValueChanged<String>? onUrlChanged;

  const HomeScreen({
    super.key,
    required this.initialUrl,
    required this.onToggleTheme,
    this.onUrlChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NativeWebViewController? _webViewController;
  final TextEditingController _urlTextController = TextEditingController();

  late String _currentUrl;
  int _loadingProgress = 0;
  bool _isLoading = false;
  final bool _isTurboActive = true;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _urlTextController.text = _currentUrl;
  }

  @override
  void dispose() {
    _urlTextController.dispose();
    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    final canGoBack = await _webViewController?.canGoBack() ?? false;
    if (canGoBack) {
      await _webViewController?.goBack();
    } else {
      final now = DateTime.now();
      if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.exit_to_app_rounded, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Press back again to close app',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        SystemNavigator.pop();
      }
    }
  }

  Future<void> _loadAndSaveUrl(String inputUrl) async {
    String formattedUrl = inputUrl.trim();
    if (formattedUrl.isEmpty) return;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    setState(() {
      _currentUrl = formattedUrl;
      _urlTextController.text = formattedUrl;
      _isLoading = true;
      _loadingProgress = 0;
    });

    widget.onUrlChanged?.call(formattedUrl);

    // Save URL persistently across app storage & remote config
    await RemoteConfigService.saveTargetUrl(formattedUrl);

    // Load target URL into native WebView without clearing cookies/session storage
    await _webViewController?.loadUrl(formattedUrl, clearCache: false);
  }

  static const List<Map<String, String>> _presetUrls = [
    {
      'title': 'Stables 365',
      'url': 'https://stables365.com/',
    },
    {
      'title': 'Kabook Sports',
      'url': 'https://kabook567.com/sports',
    },
    {
      'title': 'Reddy Books',
      'url': 'https://reddybooks.online',
    },
    {
      'title': 'Playwin321 Home',
      'url': 'https://playwin321.com/home',
    },
    {
      'title': 'Tiger365 Login',
      'url': 'https://tiger365.pro/login',
    },
  ];

  void _showChangeUrlDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.language_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('Select Web Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 16, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap any website from the list to save and load instantly.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  children: _presetUrls.map((preset) {
                    final presetUrl = preset['url']!;
                    final isCurrentActive = _currentUrl == presetUrl;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _loadAndSaveUrl(presetUrl);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrentActive
                                ? Colors.blueAccent.withOpacity(0.15)
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentActive
                                  ? Colors.blueAccent
                                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                              width: isCurrentActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCurrentActive ? Icons.check_circle_rounded : Icons.language_rounded,
                                color: isCurrentActive ? Colors.greenAccent : Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          preset['title']!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isCurrentActive
                                                ? Colors.blueAccent
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        if (isCurrentActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      presetUrl,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 2,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Back Page',
              onPressed: _handleBackNavigation,
            ),

            title: InkWell(
              onTap: _showChangeUrlDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: Colors.blueAccent,
                  size: 22,
                ),
                tooltip: 'Change Custom URL',
                onPressed: _showChangeUrlDialog,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        body: GestureDetector(
          onLongPress: _showChangeUrlDialog,
          child: Stack(
            children: [
              ProgressiveWebViewWidget(
                initialUrl: _currentUrl,
                isTurboActive: _isTurboActive,
                onRequestChangeUrl: _showChangeUrlDialog,
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgress: (progress) {
                  if (mounted && _isLoading) {
                    setState(() {
                      _loadingProgress = progress;
                      if (progress >= 100) {
                        _isLoading = false;
                      }
                    });
                  }
                },
                onPageStarted: (url) {
                  if (mounted) {
                    setState(() {
                      _currentUrl = url;
                      _urlTextController.text = url;
                      _isLoading = true;
                      _loadingProgress = 0;
                    });
                  }
                },
                onPageFinished: (url) {
                  if (mounted) {
                    setState(() {
                      _currentUrl = url;
                      _urlTextController.text = url;
                      _isLoading = false;
                      _loadingProgress = 100;
                    });
                  }
                },
              ),
              if (_isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 && _loadingProgress < 100 ? _loadingProgress / 100.0 : null,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    color: Colors.blueAccent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}





