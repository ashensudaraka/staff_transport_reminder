import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/destination.dart';

/// Allows the user to pick a location by tapping on a map.
/// Returns {'lat': double, 'lng': double} when confirmed.
class MapPickerScreen extends StatefulWidget {
  final DestinationType destinationType;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.destinationType,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapController _mapController;
  LatLng? _selectedPoint;

  // Default center: Colombo, Sri Lanka (can be adjusted)
  static const _defaultCenter = LatLng(6.9271, 79.8612);
  static const _defaultZoom = 13.0;
  static const _selectedZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPoint = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedPoint = point);
  }

  void _confirmSelection() {
    if (_selectedPoint == null) return;
    Navigator.of(context).pop({
      'lat': _selectedPoint!.latitude,
      'lng': _selectedPoint!.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHome = widget.destinationType == DestinationType.home;

    final initialCenter = _selectedPoint ?? _defaultCenter;
    final initialZoom = _selectedPoint != null ? _selectedZoom : _defaultZoom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${isHome ? 'Home' : 'Work'} Location'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_selectedPoint != null)
            FilledButton(
              onPressed: _confirmSelection,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ─── Map ───────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OpenStreetMap tiles - no API key required
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.staffapp.staff_transport_reminder',
                maxZoom: 19,
                fallbackUrl:
                    'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),

              // Selected marker
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 60,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              isHome ? Icons.home : Icons.work,
                              color: colorScheme.onPrimary,
                              size: 22,
                            ),
                          ),
                          // Pin tail
                          Container(
                            width: 3,
                            height: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ─── Instruction Banner ────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPoint == null
                          ? 'Tap on the map to set your location'
                          : 'Tap elsewhere to move the pin',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Confirm FAB ───────────────────────────────────────────────
          if (_selectedPoint != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: FilledButton.icon(
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check),
                label: Text(
                  'Set as ${isHome ? 'Home' : 'Work'} Location',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
