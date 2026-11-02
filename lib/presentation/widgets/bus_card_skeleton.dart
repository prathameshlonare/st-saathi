import 'package:flutter/material.dart';

/// Static skeleton placeholder matching the exact geometry of EnamelBusCard.
/// Eliminates layout shift during database queries.
///
/// Deliberately has no pulse animation: the timetable is on-device and answers
/// in milliseconds, so a shimmer would burn animation frames for a wait the
/// user never sees.
class BusCardSkeleton extends StatelessWidget {
  const BusCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2E2422) : const Color(0xFFEBE5DF);

    // Fixed mid-tone of the old shimmer range (0.35 to 0.85).
    const alpha = 0.6;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201817) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF332724) : const Color(0xFFE8E2DC),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Left Pillar Placeholder (Time block)
          Container(
            width: 78,
            height: 56,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          const SizedBox(width: 12),

          // Right Route Details Placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Destination Bar
                Container(
                  width: 140,
                  height: 18,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                // Secondary Destination Bar
                Container(
                  width: 85,
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: alpha * 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Via Route Bar
                Container(
                  width: 180,
                  height: 10,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: alpha * 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          // Bookmark icon placeholder
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: alpha * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
