import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'motion_alert_file_log.dart';
import 'motion_alert_preferences.dart';
import 'motion_alert_service.dart';

class MotionAlertCoordinator {
  MotionAlertCoordinator._();

  static final MotionAlertCoordinator instance = MotionAlertCoordinator._();

  final MotionAlertService _motionService = MotionAlertService();
  final ApiClient _apiClient = ApiClient();
  final MotionAlertFileLog _log = MotionAlertFileLog.instance;
  bool _initialized = false;
  bool _isSending = false;

  /// Exposes motion-hit counters so Profile can render real-time feedback.
  /// These are best-effort UX/debug signals and do not affect alert sending.
  ValueListenable<int> get hitsInWindow => _motionService.hitsInWindow;
  ValueListenable<int> get totalHits => _motionService.totalHits;
  int get minHitsInWindow => _motionService.minHitsInWindow;
  Duration get window => _motionService.window;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    MotionAlertPreferences.changes.addListener(_onSettingsChanged);
    final initial = await MotionAlertPreferences.load();
    await _applySettings(initial);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    MotionAlertPreferences.changes.removeListener(_onSettingsChanged);
    await _motionService.stop();
    _motionService.dispose();
    _initialized = false;
  }

  void _onSettingsChanged() {
    _applySettings(MotionAlertPreferences.changes.value);
  }

  Future<void> _applySettings(MotionAlertSettings settings) async {
    final canMonitor =
        settings.isEnabled && settings.alertEmail.trim().isNotEmpty;
    if (canMonitor) {
      _motionService.start(onTriggered: _onTriggered);
      return;
    }
    await _motionService.stop();
  }

  Future<void> _onTriggered(String reason) async {
    if (_isSending) return;
    _isSending = true;
    try {
      final settings = await MotionAlertPreferences.load();
      final toEmail = settings.alertEmail.trim();
      if (toEmail.isEmpty) return;

      final location = settings.location.trim();
      final studentName = settings.studentName.trim().isEmpty
          ? 'Estudiante'
          : settings.studentName.trim();

      try {
        await _apiClient.post(
          '/notifications/emergency-alert/email',
          body: {
            'toEmail': toEmail,
            'toName': 'Tutor de guardia',
            'studentName': studentName,
            'alertReason': reason,
            'location': location.isEmpty ? null : location,
          },
        );
        await _log.appendAlertEvent(
          reason: reason,
          toEmail: toEmail,
          location: location,
          success: true,
        );
      } catch (e) {
        await _log.appendAlertEvent(
          reason: reason,
          toEmail: toEmail,
          location: location,
          success: false,
          error: e.toString(),
        );
        rethrow;
      }
    } catch (_) {
      // Swallow: the failure is already recorded in the log, and this is
      // a background trigger with no user-facing surface to report to.
    } finally {
      _isSending = false;
    }
  }

  /// Clears sensitive local alert data after logout.
  ///
  /// - Stops active motion monitoring
  /// - Resets persisted alert preferences
  /// - Removes local alert history log
  Future<void> clearLocalDataForLogout() async {
    await _motionService.stop();
    await MotionAlertPreferences.clear();
    await _log.clear();
  }
}
