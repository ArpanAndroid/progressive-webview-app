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
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String initialUrl;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.initialUrl,
    required this.onToggleTheme,
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

  Future<void> _loadAndSaveUrl(String inputUrl) async {
    String formattedUrl = inputUrl.trim();
    if (formattedUrl.isEmpty) return;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    setState(() {
      _currentUrl = formattedUrl;
      _urlTextController.text = formattedUrl;
    });

    // Save URL persistently across app storage & remote config
    await RemoteConfigService.saveTargetUrl(formattedUrl);

    // Load data into native WebView and refresh
    await _webViewController?.loadUrl(formattedUrl);
    await _webViewController?.reload();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('App URL saved & loaded: $formattedUrl'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  static const List<Map<String, String>> _presetUrls = [
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
    final controller = TextEditingController(text: _currentUrl);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final currentInput = controller.text.trim();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_location_alt_rounded, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Change Web Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '72-Hour Session Persistence Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Quick Select Preset Option:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _presetUrls.map((preset) {
                        final presetUrl = preset['url']!;
                        final isSelected = currentInput == presetUrl;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                controller.text = presetUrl;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blueAccent.withOpacity(0.15)
                                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSelected ? Colors.blueAccent : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset['title']!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isSelected ? Colors.blueAccent : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
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
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Or enter target custom web URL:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      onSubmitted: (val) {
                        Navigator.pop(context);
                        _loadAndSaveUrl(val);
                      },
                      decoration: InputDecoration(
                        labelText: 'Custom URL',
                        hintText: 'https://example.com/',
                        prefixIcon: const Icon(Icons.link_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final newUrl = controller.text.trim();
                    Navigator.pop(context);
                    if (newUrl.isNotEmpty) {
                      _loadAndSaveUrl(newUrl);
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save & Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canGoBack = await _webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          await _webViewController?.goBack();
        } else {
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 1)) {
            _lastBackPressTime = now;
            if (mounted) {
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.exit_to_app_rounded, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do you want to close? Press back again to close app',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        // Clean immersive view without normal top bar
        body: GestureDetector(
          onLongPress: _showChangeUrlDialog,
          child: Stack(
            children: [
              ProgressiveWebViewWidget(
                initialUrl: _currentUrl,
                isTurboActive: _isTurboActive,
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgress: (progress) {
                  if (mounted) {
                    setState(() {
                      _loadingProgress = progress;
                      _isLoading = progress > 0 && progress < 100;
                    });
                  }
                },
                onPageStarted: (url) {
                  if (mounted) {
                    setState(() {
                      _currentUrl = url;
                      _urlTextController.text = url;
                      _isLoading = true;
                    });
                  }
                },
                onPageFinished: (url) {
                  if (mounted) {
                    setState(() {
                      _currentUrl = url;
                      _urlTextController.text = url;
                      _isLoading = false;
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
                    value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    color: Colors.blueAccent,
                  ),
                ),
              // Discrete floating menu icon button at top-right corner with ONLY ONE OPTION: Change URL
              Positioned(
                top: 40,
                right: 12,
                child: SafeArea(
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Menu',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'change_url') {
                          _showChangeUrlDialog();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'change_url',
                          child: Row(
                            children: [
                              Icon(Icons.edit_location_alt_rounded, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Change URL',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
