import 'package:shared_preferences/shared_preferences.dart';

class MotionAlertPreferences {
  MotionAlertPreferences._();

  static const String _emailKey = 'motion_alert_email';
  static const String _studentNameKey = 'motion_alert_student_name';
  static const String _locationKey = 'motion_alert_location';
  static const String _enabledKey = 'motion_alert_enabled';

  static Future<MotionAlertSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MotionAlertSettings(
      alertEmail: prefs.getString(_emailKey) ?? '',
      studentName: prefs.getString(_studentNameKey) ?? '',
      location: prefs.getString(_locationKey) ?? '',
      isEnabled: prefs.getBool(_enabledKey) ?? false,
    );
  }

  static Future<void> save(MotionAlertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_emailKey, settings.alertEmail.trim()),
      prefs.setString(_studentNameKey, settings.studentName.trim()),
      prefs.setString(_locationKey, settings.location.trim()),
      prefs.setBool(_enabledKey, settings.isEnabled),
    ]);
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
