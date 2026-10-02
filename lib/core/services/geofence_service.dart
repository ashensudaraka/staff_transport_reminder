import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../models/destination.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

// ─── Background Task Handler ─────────────────────────────────────────────────
// This runs in a separate isolate when the app is in background / screen locked.
// It polls location every 30 seconds to check proximity to the destination.

@pragma('vm:entry-point')
class GeofenceTaskHandler extends TaskHandler {
  // Prevent duplicate alerts
  bool _alertTriggered = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize services in this isolate context
    await StorageService.instance.init();
    _alertTriggered = false;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_alertTriggered) return;

    // Load active destination from storage
    final activeType = StorageService.instance.loadActiveTripType();
    if (activeType == null) {
      await FlutterForegroundTask.stopService();
      return;
    }

    final destination = StorageService.instance.loadDestination(activeType);
    if (!destination.isSaved) {
      await FlutterForegroundTask.stopService();
      return;
    }

    // Check location services
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Staff Transport Reminder',
        notificationText: '⚠ Location services disabled. Enable GPS.',
      );
      return;
    }

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final distance = LocationService.geolocatorDistance(
        position.latitude,
        position.longitude,
        destination.latitude!,
        destination.longitude!,
      );

      final distanceText = distance < 1000
          ? '${distance.toInt()} m'
          : '${(distance / 1000).toStringAsFixed(1)} km';

      // Update the persistent foreground notification
      FlutterForegroundTask.updateService(
        notificationTitle: '🚌 Trip Active – ${destination.displayName}',
        notificationText: 'Distance: $distanceText away',
      );

      // Check if within alert radius
      if (distance <= destination.alertDistanceMeters) {
        _alertTriggered = true;

        // Send data to the main isolate (if app is in foreground)
        FlutterForegroundTask.sendDataToMain({
          'event': 'destination_reached',
          'destinationType': destination.type.key,
          'distance': distance,
        });

        // Trigger high-priority notification from background isolate
        await NotificationService.instance.showArrivalNotification(
          destination: destination,
          distanceMeters: distance.toInt(),
        );

        // Clear active trip
        await StorageService.instance.saveActiveTripType(null);

        // Stop the foreground service
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      // GPS timeout or error — update notification but keep trying
      FlutterForegroundTask.updateService(
        notificationTitle: 'Staff Transport Reminder',
        notificationText: '📡 Locating... (tap to open app)',
      );
    }
  }

  @override
  void onReceiveData(Object data) {
    // Data received from main isolate (not needed currently)
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'cancel_trip') {
      StorageService.instance.saveActiveTripType(null).then((_) {
        FlutterForegroundTask.stopService();
      });
    }
  }

  @override
  void onNotificationPressed() {
    // Bring app to foreground when notification is tapped
    FlutterForegroundTask.launchApp('/active-trip');
  }

  @override
  void onNotificationDismissed() {
    // User dismissed the notification — trip still runs
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup on service destroy
  }
}

// ─── Geofence Service ────────────────────────────────────────────────────────

/// Manages the foreground service lifecycle for background geofencing.
class GeofenceService {
  static GeofenceService? _instance;
  GeofenceService._();
  static GeofenceService get instance {
    _instance ??= GeofenceService._();
    return _instance!;
  }

  void Function(Object)? _onDataCallback;

  // ─── Init ────────────────────────────────────────────────────────────────

  /// Call once at app startup to configure the foreground task settings.
  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'staff_transport_trip',
        channelName: 'Active Trip',
        channelDescription: 'Monitors your location during an active trip.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Poll every 30 seconds — balanced battery/responsiveness for vehicle travel
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // ─── Start Trip ──────────────────────────────────────────────────────────

  Future<bool> startTrip(Destination destination) async {
    // Persist active trip type so background isolate can read it
    await StorageService.instance.saveActiveTripType(destination.type);

    // Request notification permission if needed (Android 13+)
    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Stop any existing service first
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🚌 Trip Active – ${destination.displayName}',
      notificationText: 'Monitoring location...',
      notificationButtons: [
        const NotificationButton(id: 'cancel_trip', text: 'Cancel Trip'),
      ],
      callback: startForegroundTaskCallback,
    );

    return result is ServiceRequestSuccess;
  }

  // ─── Stop Trip ───────────────────────────────────────────────────────────

  Future<void> stopTrip() async {
    await StorageService.instance.saveActiveTripType(null);
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ─── Status ──────────────────────────────────────────────────────────────

  Future<bool> isTripActive() => FlutterForegroundTask.isRunningService;

  // ─── Listen for arrival events from background ────────────────────────────

  void listenForArrival(Function(Map<String, dynamic>) onData) {
    // Remove previous callback
    if (_onDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_onDataCallback!);
    }
    _onDataCallback = (Object data) {
      if (data is Map) onData(Map<String, dynamic>.from(data));
    };
    FlutterForegroundTask.addTaskDataCallback(_onDataCallback!);
  }

  void dispose() {
    if (_onDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_onDataCallback!);
      _onDataCallback = null;
    }
  }
}

// ─── Entry point for foreground task (must be top-level) ─────────────────────

@pragma('vm:entry-point')
void startForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}
