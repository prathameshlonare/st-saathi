import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/bus_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';

class EnamelBusCard extends StatefulWidget {
  final BusService service;
  final bool isMarathi;
  final bool is24Hour;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  const EnamelBusCard({
    super.key,
    required this.service,
    required this.isMarathi,
    required this.is24Hour,
    required this.isSaved,
    required this.onToggleSave,
    required this.onTap,
  });

  @override
  State<EnamelBusCard> createState() => _EnamelBusCardState();
}

class _EnamelBusCardState extends State<EnamelBusCard> {
  bool _isPressed = false;

  // Refreshes only this card's countdown badge ("in 12m", "DEPARTING NOW", …).
  // Runs on its own short cadence so the whole page does not need to rebuild.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Color _getBusTypeColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('shivneri')) return const Color(0xFF1E3A8A); // Deep Indigo
    if (lower.contains('shivshahi')) return const Color(0xFF0F766E); // Teal
    if (lower.contains('hirkani')) return const Color(0xFF15803D); // Emerald Green
    if (lower.contains('sleeper')) return const Color(0xFF6B21A8); // Purple
    if (lower.contains('semi') || lower.contains('asiad')) return const Color(0xFFB45309); // Ochre
    return AppTheme.msrtcRed; // Ordinary Lal Dabba
  }

  String _getLocalizedBusType(String type, bool isMr) {
    final lower = type.toLowerCase();
    if (isMr) {
      if (lower.contains('shivneri')) return 'शिवनेरी';
      if (lower.contains('shivshahi')) return 'शिवशाही';
      if (lower.contains('hirkani')) return 'हिरकणी';
      if (lower.contains('sleeper')) return 'शयनयान';
      if (lower.contains('semi') || lower.contains('asiad')) return 'निम-आराम';
      return 'साधी';
    } else {
      if (lower.contains('shivneri')) return 'SHIVNERI';
      if (lower.contains('shivshahi')) return 'SHIVSHAHI';
      if (lower.contains('hirkani')) return 'HIRKANI';
      if (lower.contains('sleeper')) return 'SLEEPER';
      if (lower.contains('semi') || lower.contains('asiad')) return 'SEMI-LUXURY';
      return 'ORDINARY';
    }
  }

  _TimeStatus _calculateTimeStatus() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final diff = widget.service.depMinutes - currentMinutes;

    if (diff < 0) {
      return _TimeStatus(
        label: AppStrings.get('departed', widget.isMarathi),
        isPast: true,
        isImminent: false,
        pillarBg: const Color(0xFFEBE6E1),
        statusBg: const Color(0xFF78716C).withValues(alpha: 0.12),
        textColor: const Color(0xFFB0A8A0),
      );
    } else if (diff <= 5) {
      return _TimeStatus(
        label: AppStrings.get('departs_now', widget.isMarathi),
        isPast: false,
        isImminent: true,
        pillarBg: const Color(0xFFFDE8E8),
        statusBg: const Color(0xFFDC2626).withValues(alpha: 0.15),
        textColor: const Color(0xFFDC2626),
      );
    } else if (diff <= 60) {
      final text = widget.isMarathi
          ? '${AppStrings.toDevanagariDigits(diff.toString(), true)} मिनिटांत'
          : 'in ${diff}m';
      return _TimeStatus(
        label: text,
        isPast: false,
        isImminent: true,
        pillarBg: const Color(0xFFFEF3C7),
        statusBg: const Color(0xFFD97706).withValues(alpha: 0.15),
        textColor: const Color(0xFFB45309),
      );
    } else {
      final h = diff ~/ 60;
      final m = diff % 60;
      final text = widget.isMarathi
          ? '${AppStrings.toDevanagariDigits(h.toString(), true)}तास ${AppStrings.toDevanagariDigits(m.toString(), true)}मि'
          : 'in ${h}h ${m}m';
      return _TimeStatus(
        label: text,
        isPast: false,
        isImminent: false,
        pillarBg: const Color(0xFFEFF6FF),
        statusBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
        textColor: const Color(0xFF1D4ED8),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getBusTypeColor(widget.service.busType);
    final busTypeLabel = _getLocalizedBusType(widget.service.busType, widget.isMarathi);
    final depDisplay = AppStrings.formatTime(widget.service.validDepartureTime, widget.isMarathi, widget.is24Hour);
    final timeStatus = _calculateTimeStatus();

    // Primary & Secondary Destination names for authentic bilingual plate
    final primaryDest = widget.isMarathi
        ? widget.service.destination.displayName(true)
        : widget.service.destination.displayName(false).toUpperCase();
    final secondaryDest = widget.isMarathi
        ? widget.service.destination.secondaryName(true).toUpperCase()
        : widget.service.destination.secondaryName(false);

    // MD3 Tonal Surface Container Tokens
    final cardBg = isDark ? const Color(0xFF221A19) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF554540) : const Color(0xFFE2DDD7);
    final textPrimary = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;
    final textSecondary = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (pressed) {
              setState(() => _isPressed = pressed);
            },
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: timeStatus.isPast ? 0.70 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- LEFT PILLAR: High-Contrast Time Container with Tabular Figures ---
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2220) : timeStatus.pillarBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : timeStatus.statusBg,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            depDisplay,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: widget.isMarathi
                                ? AppTheme.devanagari(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    height: 1.1,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  )
                                : AppTheme.latin(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    height: 1.1,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: timeStatus.statusBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              timeStatus.label,
                              style: widget.isMarathi
                                  ? AppTheme.devanagari(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: timeStatus.textColor,
                                      height: 1.1,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    )
                                  : AppTheme.latin(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: timeStatus.textColor,
                                      height: 1.1,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // --- RIGHT PILLAR: Route & Service Details ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Destination Header & Bus Type Pill
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      primaryDest,
                                      style: widget.isMarathi
                                          ? AppTheme.devanagari(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: textPrimary,
                                              height: 1.15,
                                            )
                                          : AppTheme.latin(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: textPrimary,
                                              height: 1.15,
                                            ),
                                      maxLines: null,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      secondaryDest,
                                      style: !widget.isMarathi
                                          ? AppTheme.devanagari(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: textSecondary,
                                            )
                                          : AppTheme.latin(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: textSecondary,
                                              letterSpacing: 0.4,
                                            ),
                                       ),
                                   ],
                                 ),
                               ),
                              const SizedBox(width: 6),

                              // Bus Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: isDark ? 0.22 : 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  busTypeLabel,
                                  style: widget.isMarathi
                                      ? AppTheme.devanagari(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: typeColor,
                                        )
                                      : AppTheme.latin(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: typeColor,
                                          letterSpacing: 0.4,
                                        ),
                                ),
                              ),
                            ],
                          ),

                          // Via Route Strip
                          if (widget.service.viaStops.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.alt_route_rounded,
                                  size: 14,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${AppStrings.get('via', widget.isMarathi)}: ${widget.service.viaStops}',
                                    style: widget.isMarathi
                                        ? AppTheme.devanagari(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          )
                                        : AppTheme.latin(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Bookmark Button
                    IconButton(
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(
                        widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: widget.isSaved ? AppTheme.msrtcGold : textSecondary.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      onPressed: widget.onToggleSave,
                      tooltip: widget.isSaved
                          ? (widget.isMarathi ? 'बुकमार्क काढा' : 'Remove bookmark')
                          : (widget.isMarathi ? 'मार्ग जतन करा' : 'Bookmark route'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _TimeStatus {
  final String label;
  final bool isPast;
  final bool isImminent;
  final Color pillarBg;
  final Color statusBg;
  final Color textColor;

  _TimeStatus({
    required this.label,
    required this.isPast,
    required this.isImminent,
    required this.pillarBg,
    required this.statusBg,
    required this.textColor,
  });
}


