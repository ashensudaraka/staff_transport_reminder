import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/destination.dart';
import '../../core/services/geofence_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import '../widgets/destination_card.dart';
import 'active_trip_screen.dart';
import 'destination_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Destination _homeDestination = const Destination(type: DestinationType.home);
  Destination _workDestination = const Destination(type: DestinationType.work);
  LocationPermission _permissionStatus = LocationPermission.denied;
  bool _locationServiceEnabled = false;
  bool _tripActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    final home = StorageService.instance.loadDestination(DestinationType.home);
    final work = StorageService.instance.loadDestination(DestinationType.work);
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final tripActive = await GeofenceService.instance.isTripActive();

    if (mounted) {
      setState(() {
        _homeDestination = home;
        _workDestination = work;
        _permissionStatus = permission;
        _locationServiceEnabled = serviceEnabled;
        _tripActive = tripActive;
      });
    }
  }

  Future<void> _startTrip(Destination destination) async {
    if (!destination.isSaved) {
      _showSnackBar('Please set the ${destination.displayName} location first.');
      return;
    }

    // Check if already in radius
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      final dist = LocationService.geolocatorDistance(
        pos.latitude, pos.longitude,
        destination.latitude!, destination.longitude!,
      );
      if (dist <= destination.alertDistanceMeters) {
        final proceed = await _showAlreadyInRadiusDialog(destination, dist.toInt());
        if (!proceed) return;
      }
    }

    // Stop any existing trip first
    if (_tripActive) {
      await GeofenceService.instance.stopTrip();
    }

    // Request permissions
    final hasPermission = await _ensurePermissions();
    if (!hasPermission) return;

    // Start the foreground service
    final started = await GeofenceService.instance.startTrip(destination);
    if (!started) {
      _showSnackBar('Failed to start trip. Please try again.');
      return;
    }

    if (!mounted) return;

    // Navigate to active trip screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(destination: destination),
        settings: const RouteSettings(name: '/active-trip'),
      ),
    );

    // Reload state when returning
    await _loadData();
  }

  Future<bool> _ensurePermissions() async {
    // Check location service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showDialog(
        title: 'Location Service Disabled',
        content: 'Please enable location/GPS services to use this app.',
        actionLabel: 'Open Settings',
        onAction: () => Geolocator.openLocationSettings(),
      );
      return false;
    }

    // Check foreground permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await _showDialog(
        title: 'Location Permission Required',
        content:
            'Location permission is permanently denied. Please enable it in app settings.',
        actionLabel: 'Open Settings',
        onAction: () => Geolocator.openAppSettings(),
      );
      return false;
    }
    if (permission == LocationPermission.denied) {
      _showSnackBar('Location permission is required to monitor your trip.');
      return false;
    }

    // Request background permission if not granted
    if (permission != LocationPermission.always) {
      await _showDialog(
        title: 'Background Location Required',
        content:
            'This app needs "Allow all the time" location permission so it can alert you when you\'re near your destination — even with the screen locked.\n\nIn the next screen, select "Allow all the time".',
        actionLabel: 'Open Settings',
        onAction: () => Geolocator.openAppSettings(),
      );
      // Re-check
      permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        _showSnackBar(
            'Background location permission is needed for trip monitoring.');
        return false;
      }
    }

    return true;
  }

  Future<bool> _showAlreadyInRadiusDialog(
      Destination dest, int distMeters) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Already Near Destination'),
        content: Text(
          'You appear to be only $distMeters m from ${dest.displayName}, which is within your alert radius.\n\nDo you still want to start the trip?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start Anyway')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showDialog({
    required String title,
    required String content,
    String actionLabel = 'OK',
    VoidCallback? onAction,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction?.call();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _editDestination(DestinationType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationScreen(destinationType: type),
      ),
    );
    await _loadData();
  }

  // ─── Permission Status Widget ─────────────────────────────────────────────

  Widget _buildPermissionStatus() {
    final bool ok = _locationServiceEnabled &&
        (_permissionStatus == LocationPermission.always ||
            _permissionStatus == LocationPermission.whileInUse);

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
            .then((_) => _loadData());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ok
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ok ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.location_on : Icons.location_off,
              size: 16,
              color: ok ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              ok ? 'Location Ready' : 'Location Issue',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ok ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const SettingsScreen()))
                        .then((_) => _loadData());
                  },
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Transport',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Reminder',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Permission Status ─────────────────────────────
                    _buildPermissionStatus(),
                    const SizedBox(height: 8),

                    if (_tripActive)
                      _buildActiveTripBanner(),

                    const SizedBox(height: 24),

                    // ─── Destination Cards ─────────────────────────────
                    Text(
                      'Your Destinations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DestinationCard(
                      destination: _homeDestination,
                      onStartTrip: () => _startTrip(_homeDestination),
                      onEdit: () => _editDestination(DestinationType.home),
                    ),
                    const SizedBox(height: 12),
                    DestinationCard(
                      destination: _workDestination,
                      onStartTrip: () => _startTrip(_workDestination),
                      onEdit: () => _editDestination(DestinationType.work),
                    ),

                    const SizedBox(height: 32),

                    // ─── How it works ──────────────────────────────────
                    _buildHowItWorks(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripBanner() {
    return GestureDetector(
      onTap: () {
        final activeType = StorageService.instance.loadActiveTripType();
        if (activeType != null) {
          final dest = StorageService.instance.loadDestination(activeType);
          Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => ActiveTripScreen(destination: dest)))
              .then((_) => _loadData());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.green),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trip is Active — Tap to view',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _howItWorksStep('1', 'Save your Home and Work locations'),
          _howItWorksStep('2', 'Board the staff bus and open the app'),
          _howItWorksStep('3', 'Tap Start Trip for your destination'),
          _howItWorksStep('4', 'Lock your phone and relax'),
          _howItWorksStep('5', 'Get alerted when you\'re nearby!'),
        ],
      ),
    );
  }

  Widget _howItWorksStep(String number, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
