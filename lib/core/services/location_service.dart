import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Provides GPS location access.
/// Does NOT poll continuously — callers request a single position when needed.
class LocationService {
  static LocationService? _instance;
  LocationService._();
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  // ─── Permission Checks ───────────────────────────────────────────────────

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> getPermissionStatus() =>
      Geolocator.checkPermission();

  /// Requests foreground location permission.
  /// Returns true if granted (whileInUse or always).
  Future<bool> requestForegroundPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Checks if background location ("always") is granted.
  Future<bool> hasBackgroundPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always;
  }

  /// Opens app settings so the user can grant "Always Allow".
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ─── Single Fix ──────────────────────────────────────────────────────────

  /// Returns the current position with balanced accuracy.
  /// Balanced accuracy uses both GPS and network — good battery/accuracy trade-off.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestForegroundPermission();
    if (!hasPermission) return null;

    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // ─── Distance Calculation ────────────────────────────────────────────────

  /// Calculates the great-circle distance between two coordinates in metres.
  static double distanceBetween(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // metres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Uses Geolocator's built-in distance calculation.
  static double geolocatorDistance(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
