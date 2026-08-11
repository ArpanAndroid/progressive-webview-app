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
        appBarTheme: const AppBarTheme(
          elevation: 2,
          scrolledUnderElevation: 2,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          scrolledUnderElevation: 2,
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
        ),
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

    // Save URL persistently across full app storage & remote config
    await RemoteConfigService.saveTargetUrl(formattedUrl);

    // Load data into native WebView and trigger reload
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
                child: Text('App URL updated & refreshed: $formattedUrl'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showChangeUrlDialog() {
    final controller = TextEditingController(text: _currentUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_location_alt_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('Change App Web Address'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter target website URL to save and load across the full app view:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (val) {
                  Navigator.pop(context);
                  _loadAndSaveUrl(val);
                },
                decoration: InputDecoration(
                  labelText: 'Target Website URL',
                  hintText: 'https://stables365.com/',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canGoBack = await _webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          await _webViewController?.goBack();
        } else {
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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
                  duration: const Duration(seconds: 2),
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
        // Top Action Bar
        appBar: AppBar(
          toolbarHeight: 50.0,
          elevation: 2,
          titleSpacing: 10,
          title: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: InkWell(
              onTap: _showChangeUrlDialog,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            // Prominent Change URL Action Button
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: OutlinedButton.icon(
                onPressed: _showChangeUrlDialog,
                icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                label: const Text(
                  'Change URL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  side: const BorderSide(color: Colors.blueAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            // Refresh Button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'Refresh App',
              onPressed: () => _webViewController?.reload(),
            ),
            // Popup Menu Options
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'Options',
              onSelected: (value) async {
                if (value == 'change_url') {
                  _showChangeUrlDialog();
                } else if (value == 'refresh') {
                  _webViewController?.reload();
                } else if (value == 'clear_cache') {
                  await _webViewController?.clearCache();
                  await _webViewController?.reload();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared & app refreshed.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else if (value == 'toggle_theme') {
                  widget.onToggleTheme();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change_url',
                  child: Row(
                    children: [
                      Icon(Icons.edit_location_alt_rounded, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text('Change Web Address'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Refresh App'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_rounded, size: 18, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Clear Cache & Reload'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'toggle_theme',
                  child: Row(
                    children: [
                      Icon(Icons.brightness_6_rounded, size: 18, color: Colors.purple),
                      SizedBox(width: 10),
                      Text('Toggle Theme'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
