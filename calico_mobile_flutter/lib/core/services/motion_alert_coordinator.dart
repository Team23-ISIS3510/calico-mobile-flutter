import '../network/api_client.dart';
import 'motion_alert_preferences.dart';
import 'motion_alert_service.dart';

class MotionAlertCoordinator {
  MotionAlertCoordinator._();

  static final MotionAlertCoordinator instance = MotionAlertCoordinator._();

  final MotionAlertService _motionService = MotionAlertService();
  final ApiClient _apiClient = ApiClient();
  bool _initialized = false;
  bool _isSending = false;

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
      if (settings.alertEmail.trim().isEmpty) return;
      await _apiClient.post(
        '/notifications/emergency-alert/email',
        body: {
          'toEmail': settings.alertEmail.trim(),
          'toName': 'Tutor de guardia',
          'studentName': settings.studentName.trim().isEmpty
              ? 'Estudiante'
              : settings.studentName.trim(),
          'alertReason': reason,
          'location': settings.location.trim().isEmpty
              ? null
              : settings.location.trim(),
        },
      );
    } finally {
      _isSending = false;
    }
  }
}
