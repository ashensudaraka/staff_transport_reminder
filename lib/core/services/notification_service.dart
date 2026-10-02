import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/destination.dart';

/// Handles all notification delivery: arrival alerts and test notifications.
class NotificationService {
  static NotificationService? _instance;
  NotificationService._();
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _arrivalChannelId = 'staff_transport_arrival';
  static const String _arrivalChannelName = 'Arrival Alerts';
  static const int _arrivalNotificationId = 2001;
  static const int _testNotificationId = 2002;

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create the high-priority arrival alert channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _arrivalChannelId,
            _arrivalChannelName,
            description: 'Alerts when you are near your destination.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );
  }

  void _onNotificationResponse(NotificationResponse response) {
    // User tapped the notification — handled by the app's navigation
  }

  // ─── Arrival Notification ─────────────────────────────────────────────────

  /// Triggers the high-priority arrival alert notification.
  /// Can be called from both foreground and background isolates.
  Future<void> showArrivalNotification({
    required Destination destination,
    required int distanceMeters,
  }) async {
    // Trigger vibration pattern first
    _triggerVibration();

    final distanceText = distanceMeters < 1000
        ? '$distanceMeters m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    final androidDetails = AndroidNotificationDetails(
      _arrivalChannelId,
      _arrivalChannelName,
      channelDescription: 'Alerts when you are near your destination.',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      playSound: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        'You are approximately $distanceText from ${destination.displayName}.\n\n'
        'Get ready to get down.',
        contentTitle: '🔔 Approaching ${destination.displayName}',
        summaryText: 'Staff Transport Reminder',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _arrivalNotificationId,
      '🔔 Approaching ${destination.displayName}',
      'Within $distanceText of ${destination.displayName}. Get ready!',
      details,
    );
  }

  // ─── Test Notification ────────────────────────────────────────────────────

  Future<void> showTestNotification() async {
    _triggerVibration();

    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    final androidDetails = AndroidNotificationDetails(
      _arrivalChannelId,
      _arrivalChannelName,
      channelDescription: 'Alerts when you are near your destination.',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      playSound: true,
      styleInformation: const BigTextStyleInformation(
        'You are approximately 700 m from Home.\n\nGet ready to get down.',
        contentTitle: '🔔 Approaching Home (Test)',
        summaryText: 'Staff Transport Reminder',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _testNotificationId,
      '🔔 Approaching Home (Test)',
      'This is a test notification. Your alerts will look like this!',
      details,
    );
  }

  // ─── Dismiss ─────────────────────────────────────────────────────────────

  Future<void> dismissArrivalNotification() async {
    await _plugin.cancel(_arrivalNotificationId);
  }

  // ─── Vibration ────────────────────────────────────────────────────────────

  void _triggerVibration() {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [0, 600, 200, 600, 200, 600],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    });
  }
}
