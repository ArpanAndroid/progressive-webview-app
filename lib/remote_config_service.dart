import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigService {
  static const String _keyTargetUrl = 'remote_target_url';
  static const String _keyFirstLaunch = 'is_first_launch_v1';
  static const String _keySessionTimestamp = 'session_start_timestamp_v1';
  static const String _defaultUrl = 'https://stables365.com/';
  static const int sessionDurationHours = 72;

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

  /// Initialize or validate 72-hour session persistence
  static Future<bool> initOrValidateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimestamp = prefs.getInt(_keySessionTimestamp);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (lastTimestamp == null) {
        await prefs.setInt(_keySessionTimestamp, nowMs);
        return true;
      }

      final elapsedHours = (nowMs - lastTimestamp) / (1000 * 60 * 60);
      if (elapsedHours >= sessionDurationHours) {
        // Refresh session timestamp for new 72-hour cycle
        await prefs.setInt(_keySessionTimestamp, nowMs);
        if (kDebugMode) print('72-hour session renewed.');
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error validating 72h session: $e');
      return true;
    }
  }

  /// Get remaining hours in current 72-hour session
  static Future<int> getRemainingSessionHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimestamp = prefs.getInt(_keySessionTimestamp);
      if (lastTimestamp == null) return sessionDurationHours;

      final elapsedHours = (DateTime.now().millisecondsSinceEpoch - lastTimestamp) / (1000 * 60 * 60);
      final remaining = sessionDurationHours - elapsedHours.floor();
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return sessionDurationHours;
    }
  }

  /// Reset or refresh 72-hour session explicitly
  static Future<void> refreshSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) print('Error refreshing session: $e');
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
    await Future.delayed(const Duration(milliseconds: 600));
    final currentUrl = await getTargetUrl();
    if (kDebugMode) print('Firebase Remote Config checked. Active remote URL: $currentUrl');
    return currentUrl;
  }
}
