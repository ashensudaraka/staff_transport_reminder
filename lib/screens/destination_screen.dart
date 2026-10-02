import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/destination.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import 'map_picker_screen.dart';

class DestinationScreen extends StatefulWidget {
  final DestinationType destinationType;

  const DestinationScreen({super.key, required this.destinationType});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  late Destination _destination;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _destination = StorageService.instance.loadDestination(widget.destinationType);
  }

  Future<void> _useCurrentLocation() async {
    // Check permissions first
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Please enable location/GPS services.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission is required.');
      return;
    }

    setState(() => _loading = true);

    final position = await LocationService.instance.getCurrentPosition();

    if (position == null) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Could not get current location. Please try again.');
      }
      return;
    }

    final updated = _destination.copyWith(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    await StorageService.instance.saveDestination(updated);

    if (mounted) {
      setState(() {
        _destination = updated;
        _loading = false;
      });
      _showSnackBar(
          '${_destination.displayName} location saved successfully!');
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          destinationType: widget.destinationType,
          initialLat: _destination.latitude,
          initialLng: _destination.longitude,
        ),
      ),
    );

    if (result != null) {
      final updated = _destination.copyWith(
        latitude: result['lat'],
        longitude: result['lng'],
      );
      await StorageService.instance.saveDestination(updated);
      if (mounted) {
        setState(() => _destination = updated);
        _showSnackBar(
            '${_destination.displayName} location saved successfully!');
      }
    }
  }

  Future<void> _updateAlertDistance(double distance) async {
    final updated = _destination.copyWith(alertDistanceMeters: distance);
    await StorageService.instance.saveDestination(updated);
    setState(() => _destination = updated);
  }

  Future<void> _clearLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear ${_destination.displayName} Location?'),
        content: const Text('This will remove the saved location.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final cleared = Destination(
        type: widget.destinationType,
        alertDistanceMeters: _destination.alertDistanceMeters,
      );
      await StorageService.instance.saveDestination(cleared);
      setState(() => _destination = cleared);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // Alert distance options in metres
  static const List<double> _alertDistances = [
    200, 300, 500, 700, 1000, 1500, 2000,
  ];

  String _formatDistance(double d) {
    if (d >= 1000) {
      final km = d / 1000;
      return km == km.roundToDouble()
          ? '${km.toInt()} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return '${d.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isHome = widget.destinationType == DestinationType.home;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Set ${_destination.displayName} Location'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Current Location Display ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isHome ? Icons.home : Icons.work,
                        color: colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _destination.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _destination.isSaved
                                ? '${_destination.latitude!.toStringAsFixed(5)}, ${_destination.longitude!.toStringAsFixed(5)}'
                                : 'Not saved yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _destination.isSaved
                                  ? colorScheme.onSurface.withValues(alpha: 0.6)
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_destination.isSaved)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        onPressed: _clearLocation,
                        tooltip: 'Clear location',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Set Location Options ──────────────────────────────────
              Text(
                'Set Location',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Use Current Location
              _buildOptionButton(
                context,
                icon: Icons.my_location,
                title: 'Use Current Location',
                subtitle: 'Saves your current GPS position',
                loading: _loading,
                onTap: _useCurrentLocation,
              ),
              const SizedBox(height: 10),

              // Select on Map
              _buildOptionButton(
                context,
                icon: Icons.map_outlined,
                title: 'Select on Map',
                subtitle: 'Pick a location by tapping on the map',
                onTap: _openMapPicker,
              ),

              const SizedBox(height: 28),

              // ─── Alert Distance ────────────────────────────────────────
              Text(
                'Alert Distance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You will be alerted when you are within this distance of ${_destination.displayName}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alertDistances.map((d) {
                  final selected = _destination.alertDistanceMeters == d;
                  return ChoiceChip(
                    label: Text(_formatDistance(d)),
                    selected: selected,
                    onSelected: (_) => _updateAlertDistance(d),
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // ─── Save Button ───────────────────────────────────────────
              if (_destination.isSaved)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check),
                  label: Text('Done – ${_destination.displayName} is set'),
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

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool loading = false,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
