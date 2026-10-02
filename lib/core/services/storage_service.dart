import 'package:shared_preferences/shared_preferences.dart';
import '../models/destination.dart';

/// Handles all local persistent storage using SharedPreferences.
/// Only stores destination coordinates, alert distances, and basic prefs.
class StorageService {
  static const String _homeKey = 'destination_home';
  static const String _workKey = 'destination_work';
  static const String _activeTripDestTypeKey = 'active_trip_dest_type';

  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) throw StateError('StorageService not initialized. Call init() first.');
    return _prefs!;
  }

  // ─── Destination CRUD ────────────────────────────────────────────────────

  Future<void> saveDestination(Destination destination) async {
    final key = destination.type == DestinationType.home ? _homeKey : _workKey;
    await _p.setString(key, destination.toJsonString());
  }

  Destination loadDestination(DestinationType type) {
    final key = type == DestinationType.home ? _homeKey : _workKey;
    final json = _p.getString(key);
    if (json == null) {
      return Destination(type: type);
    }
    try {
      return Destination.fromJsonString(json);
    } catch (_) {
      return Destination(type: type);
    }
  }

  // ─── Active Trip Persistence ─────────────────────────────────────────────

  /// Persists the active trip destination type so the foreground service
  /// can restore state after the UI is destroyed.
  Future<void> saveActiveTripType(DestinationType? type) async {
    if (type == null) {
      await _p.remove(_activeTripDestTypeKey);
    } else {
      await _p.setString(_activeTripDestTypeKey, type.key);
    }
  }

  DestinationType? loadActiveTripType() {
    final val = _p.getString(_activeTripDestTypeKey);
    if (val == 'home') return DestinationType.home;
    if (val == 'work') return DestinationType.work;
    return null;
  }

  // ─── Clear ───────────────────────────────────────────────────────────────

  Future<void> clearDestination(DestinationType type) async {
    final key = type == DestinationType.home ? _homeKey : _workKey;
    await _p.remove(key);
  }
}
