import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MotionAlertPreferences {
  MotionAlertPreferences._();

  static const String _emailKey = 'motion_alert_email';
  static const String _studentNameKey = 'motion_alert_student_name';
  static const String _locationKey = 'motion_alert_location';
  static const String _enabledKey = 'motion_alert_enabled';
  static MotionAlertSettings _memoryCache = const MotionAlertSettings(
    alertEmail: '',
    studentName: '',
    location: '',
    isEnabled: false,
  );
  static final ValueNotifier<MotionAlertSettings> changes =
      ValueNotifier<MotionAlertSettings>(_memoryCache);

  static Future<MotionAlertSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = MotionAlertSettings(
        alertEmail: prefs.getString(_emailKey) ?? '',
        studentName: prefs.getString(_studentNameKey) ?? '',
        location: prefs.getString(_locationKey) ?? '',
        isEnabled: prefs.getBool(_enabledKey) ?? false,
      );
      _memoryCache = loaded;
      changes.value = loaded;
      return loaded;
    } catch (_) {
      changes.value = _memoryCache;
      return _memoryCache;
    }
  }

  static Future<void> save(MotionAlertSettings settings) async {
    final normalized = MotionAlertSettings(
      alertEmail: settings.alertEmail.trim(),
      studentName: settings.studentName.trim(),
      location: settings.location.trim(),
      isEnabled: settings.isEnabled,
    );
    _memoryCache = normalized;
    changes.value = normalized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_emailKey, normalized.alertEmail),
        prefs.setString(_studentNameKey, normalized.studentName),
        prefs.setString(_locationKey, normalized.location),
        prefs.setBool(_enabledKey, normalized.isEnabled),
      ]);
    } catch (_) {
      // Fallback: keep settings in memory if plugin channel is unavailable.
    }
  }

  static Future<void> clear() async {
    const cleared = MotionAlertSettings(
      alertEmail: '',
      studentName: '',
      location: '',
      isEnabled: false,
    );
    _memoryCache = cleared;
    changes.value = cleared;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_emailKey),
        prefs.remove(_studentNameKey),
        prefs.remove(_locationKey),
        prefs.remove(_enabledKey),
      ]);
    } catch (_) {
      // Keep in-memory cleanup even when persistence fails.
    }
  }
}

class MotionAlertSettings {
  const MotionAlertSettings({
    required this.alertEmail,
    required this.studentName,
    required this.location,
    required this.isEnabled,
  });

  final String alertEmail;
  final String studentName;
  final String location;
  final bool isEnabled;

  MotionAlertSettings copyWith({
    String? alertEmail,
    String? studentName,
    String? location,
    bool? isEnabled,
  }) {
    return MotionAlertSettings(
      alertEmail: alertEmail ?? this.alertEmail,
      studentName: studentName ?? this.studentName,
      location: location ?? this.location,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
