import 'package:geolocator/geolocator.dart';

class CampusLocationService {
  // Universidad de Los Andes, Bogotá, Colombia — main campus center.
  static const double _campusLat = 4.6016;
  static const double _campusLng = -74.0660;
  static const double _radiusMeters = 500;

  /// Returns true if on campus, false if off campus, null if location is
  /// unavailable (permission denied, service disabled, or timeout).
  static Future<bool?> checkIsOnCampus() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { return null; }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 10));

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _campusLat,
        _campusLng,
      );
      return distance <= _radiusMeters;
    } catch (_) {
      return null;
    }
  }

  static bool matchesCampus(String location) {
    final l = location.toLowerCase();
    return l.contains('presencial') ||
        l.contains('campus') ||
        l.contains('in-person') ||
        l.contains('in person') ||
        l.contains('sede') ||
        l.contains('salon') ||
        l.contains('salón') ||
        l.contains('sala') ||
        l.contains('bloque');
  }

  static bool matchesVirtual(String location) {
    final l = location.toLowerCase();
    return l.contains('virtual') ||
        l.contains('online') ||
        l.contains('remoto') ||
        l.contains('remote');
  }
}
