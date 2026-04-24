import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class MotionAlertService {
  MotionAlertService({
    this.threshold = 18.0,
    this.minHitsInWindow = 5,
    this.window = const Duration(seconds: 30),
    this.cooldown = const Duration(minutes: 1),
  });
  final double threshold;
  final int minHitsInWindow;
  final Duration window;
  final Duration cooldown;

  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<DateTime> _hits = <DateTime>[];
  DateTime? _lastAlertAt;
  DateTime? _lastHitAt;

  bool get isMonitoring => _subscription != null;

  void start({
    required Future<void> Function(String reason) onTriggered,
  }) {
    if (isMonitoring) return;

    _subscription = accelerometerEventStream().listen((event) async {
      final now = DateTime.now();
      final magnitude = sqrt(
        (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
      );

      if (magnitude < threshold) return;

      if (_lastHitAt != null &&
          now.difference(_lastHitAt!) < const Duration(milliseconds: 700)) {
        return;
      }
      _lastHitAt = now;

      _hits.add(now);
      _hits.removeWhere((hit) => now.difference(hit) > window);

      if (_hits.length < minHitsInWindow) return;
      if (_lastAlertAt != null && now.difference(_lastAlertAt!) < cooldown) {
        return;
      }

      _lastAlertAt = now;
      _hits.clear();
      await onTriggered(
        'Se detectaron $minHitsInWindow movimientos bruscos en ${window.inSeconds} segundos.',
      );
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _hits.clear();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _hits.clear();
  }
}
