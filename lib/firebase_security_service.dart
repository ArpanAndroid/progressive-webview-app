import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApprovalStatus {
  final bool isApproved;
  final String statusMessage;
  final String deviceKey;
  final String firebaseDbUrl;
  final bool isLocalBypass;
  final DateTime? lastChecked;

  ApprovalStatus({
    required this.isApproved,
    required this.statusMessage,
    required this.deviceKey,
    required this.firebaseDbUrl,
    this.isLocalBypass = false,
    this.lastChecked,
  });
}

class FirebaseSecurityService {
  static const String _keyDeviceLicenseKey = 'device_license_key_v1';
  static const String _keyFirebaseDbUrl = 'firebase_db_url_v1';
  static const String _keyLocalApprovalOverride = 'local_approval_override_v1';

  static const String defaultFirebaseDbUrl = 'https://stables365-security-default-rtdb.firebaseio.com/';
  static const String defaultMasterKey = 'STABLES-ADMIN-777';

  /// Toggle flag: Currently set to false to disable Firebase Security Gating
  static bool enableSecurityGate = false;

  /// Fetch or auto-generate unique persistent Device Key
  static Future<String> getDeviceKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? key = prefs.getString(_keyDeviceLicenseKey);
      if (key == null || key.isEmpty) {
        key = _generateUniqueDeviceKey();
        await prefs.setString(_keyDeviceLicenseKey, key);
      }
      return key;
    } catch (e) {
      return 'KEY-8A39F12B';
    }
  }

  /// Generate a clean readable device key e.g. KEY-A9B2-C4D8
  static String _generateUniqueDeviceKey() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String part1 = List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    String part2 = List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    return 'KEY-$part1-$part2';
  }

  /// Get configured Firebase DB URL
  static Future<String> getFirebaseDbUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyFirebaseDbUrl) ?? defaultFirebaseDbUrl;
    } catch (e) {
      return defaultFirebaseDbUrl;
    }
  }

  /// Update Firebase DB URL dynamically
  static Future<bool> setFirebaseDbUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String formattedUrl = url.trim();
      if (formattedUrl.isNotEmpty && !formattedUrl.endsWith('/')) {
        formattedUrl = '$formattedUrl/';
      }
      return await prefs.setString(_keyFirebaseDbUrl, formattedUrl);
    } catch (e) {
      return false;
    }
  }

  /// Check if device has local admin override approval
  static Future<bool> isLocallyApproved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyLocalApprovalOverride) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Grant or revoke local admin approval override
  static Future<void> setLocalApprovalOverride(bool approved) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLocalApprovalOverride, approved);
    } catch (e) {
      if (kDebugMode) print('Error setting local approval override: $e');
    }
  }

  /// Main Approval Check Engine using Firebase Realtime Database REST API
  static Future<ApprovalStatus> checkDeviceApproval() async {
    final deviceKey = await getDeviceKey();
    final dbUrl = await getFirebaseDbUrl();
    final localOverride = await isLocallyApproved();

    if (!enableSecurityGate || localOverride) {
      return ApprovalStatus(
        isApproved: true,
        statusMessage: enableSecurityGate ? 'Unlocked via Admin Master Key' : 'Firebase Security Currently Disabled',
        deviceKey: deviceKey,
        firebaseDbUrl: dbUrl,
        isLocalBypass: true,
        lastChecked: DateTime.now(),
      );
    }

    try {
      final endpoint = '${dbUrl}devices/$deviceKey.json';
      if (kDebugMode) print('Checking Firebase DB API approval: $endpoint');

      final response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = response.body.trim();

        if (body == 'null' || body.isEmpty) {
          // Device key is not registered in Firebase DB yet -> Auto-Register as Pending!
          await _registerDeviceInFirebase(dbUrl, deviceKey);
          return ApprovalStatus(
            isApproved: false,
            statusMessage: 'Device Registered in Firebase. Pending Admin Approval.',
            deviceKey: deviceKey,
            firebaseDbUrl: dbUrl,
            lastChecked: DateTime.now(),
          );
        }

        final data = json.decode(body) as Map<String, dynamic>;
        final bool approved = data['approved'] == true;
        final String status = data['status'] as String? ?? (approved ? 'Approved by Admin' : 'Pending Admin Approval');

        // Update last checked timestamp in Firebase DB async
        _touchLastCheckTime(dbUrl, deviceKey);

        return ApprovalStatus(
          isApproved: approved,
          statusMessage: approved ? 'Access Granted by Firebase Admin' : status,
          deviceKey: deviceKey,
          firebaseDbUrl: dbUrl,
          lastChecked: DateTime.now(),
        );
      } else {
        return ApprovalStatus(
          isApproved: false,
          statusMessage: 'Firebase API Error (${response.statusCode}). Waiting for Admin.',
          deviceKey: deviceKey,
          firebaseDbUrl: dbUrl,
          lastChecked: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Firebase Security Check Exception: $e');
      // If offline/error but was previously registered, require online approval or master key
      return ApprovalStatus(
        isApproved: false,
        statusMessage: 'Network Connection Required to Verify Firebase License',
        deviceKey: deviceKey,
        firebaseDbUrl: dbUrl,
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Automatically register new APK device key in Firebase DB with approved: false
  static Future<void> _registerDeviceInFirebase(String dbUrl, String deviceKey) async {
    try {
      final endpoint = '${dbUrl}devices/$deviceKey.json';
      final payload = {
        'device_key': deviceKey,
        'approved': false,
        'status': 'Pending Admin Approval',
        'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
        'registered_at': DateTime.now().toIso8601String(),
        'last_check': DateTime.now().toIso8601String(),
        'notes': 'Change "approved" to true in Firebase Console to grant APK access.',
      };

      await http.put(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 6));
    } catch (e) {
      if (kDebugMode) print('Error auto-registering device in Firebase DB: $e');
    }
  }

  /// Update last check timestamp in Firebase DB
  static Future<void> _touchLastCheckTime(String dbUrl, String deviceKey) async {
    try {
      final endpoint = '${dbUrl}devices/$deviceKey/last_check.json';
      await http.put(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(DateTime.now().toIso8601String()),
      );
    } catch (_) {}
  }

  /// Validate Admin Master Key override
  static Future<bool> verifyAndUnlockWithMasterKey(String inputKey) async {
    if (inputKey.trim() == defaultMasterKey) {
      await setLocalApprovalOverride(true);
      return true;
    }
    return false;
  }
}
