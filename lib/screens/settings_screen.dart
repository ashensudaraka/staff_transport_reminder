import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/destination.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  LocationPermission _permission = LocationPermission.denied;
  bool _locationServiceEnabled = false;
  Destination _homeDestination = const Destination(type: DestinationType.home);
  Destination _workDestination = const Destination(type: DestinationType.work);
  bool _testNotifSent = false;

  static const List<double> _alertDistances = [
    200, 300, 500, 700, 1000, 1500, 2000,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final home = StorageService.instance.loadDestination(DestinationType.home);
    final work = StorageService.instance.loadDestination(DestinationType.work);

    if (mounted) {
      setState(() {
        _permission = permission;
        _locationServiceEnabled = serviceEnabled;
        _homeDestination = home;
        _workDestination = work;
      });
    }
  }

  Future<void> _updateAlertDistance(DestinationType type, double distance) async {
    if (type == DestinationType.home) {
      final updated = _homeDestination.copyWith(alertDistanceMeters: distance);
      await StorageService.instance.saveDestination(updated);
      setState(() => _homeDestination = updated);
    } else {
      final updated = _workDestination.copyWith(alertDistanceMeters: distance);
      await StorageService.instance.saveDestination(updated);
      setState(() => _workDestination = updated);
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showTestNotification();
    setState(() => _testNotifSent = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _testNotifSent = false);
    });
  }

  String _formatDistance(double d) {
    if (d >= 1000) {
      final km = d / 1000;
      return km == km.roundToDouble()
          ? '${km.toInt()} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return '${d.toInt()} m';
  }

  String _permissionLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return 'Always (Background ✓)';
      case LocationPermission.whileInUse:
        return 'While in use only';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Permanently Denied';
      case LocationPermission.unableToDetermine:
        return 'Unknown';
    }
  }

  Color _permissionColor(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return Colors.green;
      case LocationPermission.whileInUse:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Location Permissions ──────────────────────────────────────
            _buildSectionTitle(context, 'Location Permissions'),
            const SizedBox(height: 10),

            _buildStatusTile(
              context,
              icon: Icons.location_on,
              title: 'Location Service (GPS)',
              value: _locationServiceEnabled ? 'Enabled' : 'Disabled',
              color: _locationServiceEnabled ? Colors.green : Colors.red,
              onTap: !_locationServiceEnabled
                  ? () => Geolocator.openLocationSettings()
                  : null,
              actionLabel:
                  !_locationServiceEnabled ? 'Enable' : null,
            ),
            const SizedBox(height: 8),

            _buildStatusTile(
              context,
              icon: Icons.security,
              title: 'Location Permission',
              value: _permissionLabel(_permission),
              color: _permissionColor(_permission),
              onTap: _permission != LocationPermission.always
                  ? () => Geolocator.openAppSettings().then((_) => _loadData())
                  : null,
              actionLabel: _permission != LocationPermission.always
                  ? 'Fix'
                  : null,
            ),

            if (_permission == LocationPermission.whileInUse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Background location is not granted. The app needs "Allow all the time" to alert you when the screen is locked.\n\nGo to Settings → Apps → Staff Transport Reminder → Permissions → Location → Allow all the time.',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ─── Alert Distances ────────────────────────────────────────
            _buildSectionTitle(context, 'Alert Distances'),
            const SizedBox(height: 10),

            _buildDistanceSelector(
              context,
              type: DestinationType.home,
              currentDistance: _homeDestination.alertDistanceMeters,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _buildDistanceSelector(
              context,
              type: DestinationType.work,
              currentDistance: _workDestination.alertDistanceMeters,
              colorScheme: colorScheme,
            ),

            const SizedBox(height: 24),

            // ─── Notifications ─────────────────────────────────────────
            _buildSectionTitle(context, 'Notifications'),
            const SizedBox(height: 10),

            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.3))),
              leading: Icon(Icons.notifications_active,
                  color: colorScheme.primary),
              title: const Text('Test Notification'),
              subtitle: const Text(
                  'Sends a sample arrival notification to verify it works.'),
              trailing: _testNotifSent
                  ? const Icon(Icons.check, color: Colors.green)
                  : const Icon(Icons.chevron_right),
              onTap: _sendTestNotification,
            ),

            const SizedBox(height: 24),

            // ─── Battery Optimization ───────────────────────────────────
            _buildSectionTitle(context, 'Battery Optimization'),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'For reliable alerts, disable battery optimization for this app.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Go to: Settings → Battery → Battery Optimization → All Apps → Staff Transport Reminder → Don\'t optimize',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      const url =
                          'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS';
                      try {
                        await launchUrl(Uri.parse('package:$url'));
                      } catch (_) {
                        await Geolocator.openAppSettings();
                      }
                    },
                    icon: const Icon(Icons.battery_saver_outlined),
                    label: const Text('Open Battery Settings'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── About ────────────────────────────────────────────────
            _buildSectionTitle(context, 'About'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Staff Transport Reminder',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Version 1.0.0',
                      style: TextStyle(fontSize: 12)),
                  SizedBox(height: 8),
                  Text(
                    'This app uses GPS to alert you when you are approaching your saved Home or Work destination while travelling on staff transport.',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'No data is collected or stored on servers. All data is stored locally on your device.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _buildStatusTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value, style: TextStyle(color: color)),
      trailing: onTap != null
          ? TextButton(
              onPressed: onTap,
              child: Text(actionLabel ?? 'Fix'),
            )
          : Icon(Icons.check_circle, color: color, size: 20),
    );
  }

  Widget _buildDistanceSelector(
    BuildContext context, {
    required DestinationType type,
    required double currentDistance,
    required ColorScheme colorScheme,
  }) {
    final isHome = type == DestinationType.home;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHome ? Icons.home : Icons.work,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${isHome ? 'Home' : 'Work'} Alert Distance',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _formatDistance(currentDistance),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _alertDistances.map((d) {
              final selected = currentDistance == d;
              return ChoiceChip(
                label: Text(_formatDistance(d),
                    style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => _updateAlertDistance(type, d),
                selectedColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
