import 'package:flutter/material.dart';
import 'remote_config_service.dart';

class FirstTimePermissionScreen extends StatefulWidget {
  final String initialUrl;
  final VoidCallback onPermissionGranted;

  const FirstTimePermissionScreen({
    super.key,
    required this.initialUrl,
    required this.onPermissionGranted,
  });

  @override
  State<FirstTimePermissionScreen> createState() => _FirstTimePermissionScreenState();
}

class _FirstTimePermissionScreenState extends State<FirstTimePermissionScreen> {
  late TextEditingController _urlController;
  bool _internetGranted = true;
  bool _storageGranted = true;
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _proceedToApp() async {
    final customUrl = _urlController.text.trim();
    if (customUrl.isNotEmpty) {
      await RemoteConfigService.saveTargetUrl(customUrl);
    }
    await RemoteConfigService.setFirstLaunchCompleted();
    widget.onPermissionGranted();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header Icon & Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_update_good_rounded,
                    size: 56,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Welcome to Progressive App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Configure initial permissions and remote web settings for your first launch experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Permissions List Card
              Text(
                'Required App Capabilities',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _internetGranted,
                      onChanged: (val) => setState(() => _internetGranted = val),
                      secondary: const Icon(Icons.wifi_rounded, color: Colors.blueAccent),
                      title: const Text('Internet & Network Access'),
                      subtitle: const Text('Connects to progressive web servers & Firebase Remote Config'),
                      activeColor: Colors.blueAccent,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      value: _storageGranted,
                      onChanged: (val) => setState(() => _storageGranted = val),
                      secondary: const Icon(Icons.storage_rounded, color: Colors.amber),
                      title: const Text('DOM Storage & PWA Caching'),
                      subtitle: const Text('Enables offline web cache, localStorage & Service Workers'),
                      activeColor: Colors.amber,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      value: _locationGranted,
                      onChanged: (val) => setState(() => _locationGranted = val),
                      secondary: const Icon(Icons.my_location_rounded, color: Colors.green),
                      title: const Text('Optional Geolocation Access'),
                      subtitle: const Text('Allows embedded web apps to request position if needed'),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Target URL Config Input
              Text(
                'Target Web Address (Firebase Remote URL)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Default Web Application URL',
                  hintText: 'https://stables365.com/',
                  prefixIcon: const Icon(Icons.link_rounded, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
              ),
              const SizedBox(height: 36),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _internetGranted ? _proceedToApp : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Grant Permission & Get Started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Permissions can be updated anytime in app settings.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
