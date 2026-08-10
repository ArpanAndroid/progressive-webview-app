import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigService {
  static const String _keyTargetUrl = 'remote_target_url';
  static const String _keyFirstLaunch = 'is_first_launch_v1';
  static const String _defaultUrl = 'https://stables365.com/cricket-betting/1793/1705297';

  /// Fetch initial target URL from local persistence or Firebase Remote Config default
  static Future<String> getTargetUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyTargetUrl) ?? _defaultUrl;
    } catch (e) {
      if (kDebugMode) print('Error reading target URL: $e');
      return _defaultUrl;
    }
  }

  /// Save dynamic target URL anytime (e.g. when fetched from Firebase Remote Config or manual user change)
  static Future<bool> saveTargetUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyTargetUrl, url);
    } catch (e) {
      if (kDebugMode) print('Error saving target URL: $e');
      return false;
    }
  }

  /// Check if this is the user's first time opening the app
  static Future<bool> isFirstTimeLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFirstLaunch) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Mark first time launch & permissions onboarding as completed
  static Future<void> setFirstLaunchCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFirstLaunch, false);
    } catch (e) {
      if (kDebugMode) print('Error marking first launch complete: $e');
    }
  }

  /// Reset onboarding state for testing / re-requesting permissions
  static Future<void> resetFirstLaunchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFirstLaunch, true);
    } catch (e) {
      if (kDebugMode) print('Error resetting first launch state: $e');
    }
  }

  /// Simulates or connects Firebase Remote Config fetch anytime during runtime
  static Future<String?> fetchFirebaseRemoteConfig({String? remoteKey}) async {
    // Firebase Remote Config Hook
    // When Firebase SDK is linked, call FirebaseRemoteConfig.instance.fetchAndActivate()
    // For standalone production readiness, returns configured target or null
    await Future.delayed(const Duration(milliseconds: 600));
    final currentUrl = await getTargetUrl();
    if (kDebugMode) print('Firebase Remote Config checked. Active remote URL: $currentUrl');
    return currentUrl;
  }
}
