import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/destination.dart';
import '../../core/services/geofence_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';

class ActiveTripScreen extends StatefulWidget {
  final Destination destination;

  const ActiveTripScreen({super.key, required this.destination});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with WidgetsBindingObserver {
  bool _arrived = false;
  String _statusText = 'Monitoring your destination...';
  String _distanceText = '—';
  Timer? _uiRefreshTimer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for arrival events from the background service
    GeofenceService.instance.listenForArrival((data) {
      if (data['event'] == 'destination_reached' && mounted) {
        _onArrived();
      }
    });

    // Refresh UI distance estimate every 30 seconds when app is in foreground
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_arrived) _updateDistance();
    });

    _updateDistance();
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    GeofenceService.instance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateDistance();
      _checkIfArrived();
    }
  }

  Future<void> _checkIfArrived() async {
    final isActive = await GeofenceService.instance.isTripActive();
    if (!isActive && !_arrived && mounted) {
      _onArrived();
    }
  }

  Future<void> _updateDistance() async {
    if (!mounted || _arrived) return;
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      final dist = LocationService.geolocatorDistance(
        pos.latitude, pos.longitude,
        widget.destination.latitude!, widget.destination.longitude!,
      );
      setState(() {
        _distanceText = dist < 1000
            ? '${dist.toInt()} m'
            : '${(dist / 1000).toStringAsFixed(1)} km';
      });
    }
  }

  void _onArrived() {
    if (!mounted) return;
    setState(() {
      _arrived = true;
      _statusText = 'You have arrived!';
    });
    _uiRefreshTimer?.cancel();
    _showArrivalDialog();
  }

  Future<void> _showArrivalDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(
          'Approaching ${widget.destination.displayName}',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You are within ${widget.destination.alertDistanceLabel} of your destination.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Get ready to get down!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Return to home
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
            'Are you sure you want to cancel the current trip? You will not receive the arrival alert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Trip')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cancelling = true);
      await GeofenceService.instance.stopTrip();
      await NotificationService.instance.dismissArrivalNotification();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Active Trip'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Status Card ────────────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated pulsing icon
                    _buildStatusIcon(colorScheme),
                    const SizedBox(height: 32),

                    // Trip details
                    _buildInfoRow(
                      context,
                      icon: Icons.location_on,
                      label: 'Destination',
                      value: widget.destination.displayName,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      icon: Icons.radar,
                      label: 'Alert radius',
                      value: widget.destination.alertDistanceLabel,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      icon: Icons.navigation,
                      label: 'Distance',
                      value: _distanceText,
                    ),
                    const SizedBox(height: 32),

                    // Status text
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: (_arrived ? Colors.green : colorScheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _arrived ? Colors.green : colorScheme.primary,
                        ),
                      ),
                    ),

                    if (!_arrived) ...[
                      const SizedBox(height: 20),
                      Text(
                        'You can lock your phone.\nThe alert will wake your screen.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ─── Cancel Button ──────────────────────────────────────────
              if (!_arrived)
                FilledButton.icon(
                  onPressed: _cancelling ? null : _cancelTrip,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel Trip'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('Back to Home'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    if (_arrived) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.where_to_vote, size: 60, color: Colors.green),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.05),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.destination.type == DestinationType.home
              ? Icons.home_outlined
              : Icons.work_outline,
          size: 60,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
