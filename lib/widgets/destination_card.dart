import 'package:flutter/material.dart';
import '../../core/models/destination.dart';

/// Card widget displayed on the Home screen for each destination (Home/Work).
class DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onStartTrip;
  final VoidCallback onEdit;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.onStartTrip,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isHome = destination.type == DestinationType.home;
    final isSaved = destination.isSaved;

    // Color accent per destination type
    final accent = isHome
        ? const Color(0xFF4CAF50) // Green for home
        : const Color(0xFF2196F3); // Blue for work

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSaved ? accent.withValues(alpha: 0.3) : colorScheme.outline.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHome ? Icons.home_rounded : Icons.work_rounded,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.displayName.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isSaved
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 14,
                            color: isSaved
                                ? Colors.green
                                : colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSaved ? 'Location saved' : 'Not saved yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSaved
                                  ? Colors.green
                                  : colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ─── Info Row ────────────────────────────────────────────────
            if (isSaved) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'Alert at ',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      destination.alertDistanceLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.location_on, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${destination.latitude!.toStringAsFixed(4)}, '
                      '${destination.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Action Buttons ──────────────────────────────────────────
            Row(
              children: [
                // Start Trip (primary action)
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: onStartTrip,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Start Trip',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: isSaved ? accent : colorScheme.surfaceContainerHighest,
                      foregroundColor: isSaved ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.4),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      isSaved ? Icons.edit_outlined : Icons.add_location_alt_outlined,
                      size: 18,
                    ),
                    label: Text(
                      isSaved ? 'Edit' : 'Set Up',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: accent.withValues(alpha: 0.5)),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
