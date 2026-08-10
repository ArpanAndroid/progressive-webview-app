import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_webview_controller.dart';
import 'progressive_webview_widget.dart';
import 'remote_config_service.dart';

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
  String _initialUrl = 'https://stables365.com/cricket-betting/1793/1705297';
  bool _isLoadingInit = true;

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
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: '',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFA8B4C0),
        appBarTheme: const AppBarTheme(
          elevation: 1,
          scrolledUnderElevation: 1,
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
          elevation: 1,
          scrolledUnderElevation: 1,
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
  bool _isTurboActive = true;


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

    // Save URL persistently in local storage & remote config
    await RemoteConfigService.saveTargetUrl(formattedUrl);

    // Load data into native WebView
    await _webViewController?.loadUrl(formattedUrl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Saved and loading: $formattedUrl'),
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
              Text('Change Web Address'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter target web URL to save and load data into the native view:',
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
                  labelText: 'Website URL',
                  hintText: 'https://stables365.com/cricket-betting/1793/1705297',
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
              label: const Text('Save & Load Data'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_cricket_rounded, color: Colors.amberAccent, size: 22),
          ],
        ),

        actions: [
          // Options Menu Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'refresh') {
                _webViewController?.reload();
              } else if (value == 'change_url') {
                _showChangeUrlDialog();
              } else if (value == 'toggle_theme') {
                widget.onToggleTheme();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'change_url',
                child: Row(
                  children: [
                    Icon(Icons.edit_location_alt_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Change URL'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(Icons.brightness_6_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 12),
                    Text('Toggle Theme'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Clean Body with Progressive WebView
      body: ProgressiveWebViewWidget(
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
    );
  }
}

