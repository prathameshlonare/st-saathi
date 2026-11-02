import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/connecting_route.dart';
import '../../models/bus_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/app_state.dart';
import '../screens/service_detail_screen.dart';

class ConnectingRouteCard extends StatefulWidget {
  final ConnectingRoute route;
  final AppState appState;

  const ConnectingRouteCard({
    super.key,
    required this.route,
    required this.appState,
  });

  @override
  State<ConnectingRouteCard> createState() => _ConnectingRouteCardState();
}

class _ConnectingRouteCardState extends State<ConnectingRouteCard> {
  bool _isExpanded = false;

  void _openDetail(BusService service) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          service: service,
          appState: widget.appState,
          isSaved: false,
          onToggleSave: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final route = widget.route;
    final isMarathi = widget.appState.isMarathi;

    final surfaceCard = isDark ? const Color(0xFF221A19) : Colors.white;
    final borderCard = isDark ? const Color(0xFF382C29) : AppTheme.outline;
    final textMain = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;
    final textMuted = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;

    final leg1Next = route.leg1Services.take(3).toList();
    final leg2Next = route.leg2Services.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCard, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Junction Name & Total Daily Connections
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.msrtcGold.withValues(alpha: isDark ? 0.15 : 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: borderCard)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.msrtcGold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.alt_route_rounded, size: 18, color: AppTheme.msrtcGoldDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMarathi
                            ? '${route.junction.displayName(true)} येथे बदला'
                            : 'Change at ${route.junction.displayName(false)}',
                        style: isMarathi
                            ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.w800, color: textMain)
                            : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
                      ),
                      Text(
                        isMarathi
                            ? 'मध्यवर्ती कनेक्टिंग आगार'
                            : 'Intermediate Transfer Hub',
                        style: isMarathi
                            ? AppTheme.devanagari(fontSize: 11, color: textMuted)
                            : AppTheme.latin(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.msrtcRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.msrtcRed.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    isMarathi
                        ? '${AppStrings.toDevanagariDigits(route.totalFrequencyScore.toString(), true)} बसेस/दिवस'
                        : '${route.totalFrequencyScore} buses/day',
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.msrtcRed)
                        : AppTheme.latin(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.msrtcRed),
                  ),
                ),
              ],
            ),
          ),

          // Two-Stage Journey Diagram
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leg 1 Block
                _buildLegRow(
                  legNumber: '१',
                  legNumberEn: '1',
                  fromStation: route.leg1Services.first.origin.displayName(isMarathi),
                  toStation: route.junction.displayName(isMarathi),
                  busCount: route.leg1Count,
                  services: leg1Next,
                  isDark: isDark,
                  textMain: textMain,
                  textMuted: textMuted,
                  isMarathi: isMarathi,
                  onSelectService: _openDetail,
                ),

                // Transfer Bridge Indicator
                Padding(
                  padding: const EdgeInsets.only(left: 15, top: 2, bottom: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 28,
                        color: AppTheme.msrtcGoldDark,
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2220) : const Color(0xFFF5EBE6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.transfer_within_a_station_rounded, size: 14, color: AppTheme.msrtcGoldDark),
                            const SizedBox(width: 6),
                            Text(
                              isMarathi
                                  ? '${route.junction.displayName(true)} आगारामध्ये गाडी बदला'
                                  : 'Switch buses at ${route.junction.displayName(false)} Depot',
                              style: isMarathi
                                  ? AppTheme.devanagari(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.msrtcGoldDark)
                                  : AppTheme.latin(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.msrtcGoldDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Leg 2 Block
                _buildLegRow(
                  legNumber: '२',
                  legNumberEn: '2',
                  fromStation: route.junction.displayName(isMarathi),
                  toStation: route.leg2Services.first.destination.displayName(isMarathi),
                  busCount: route.leg2Count,
                  services: leg2Next,
                  isDark: isDark,
                  textMain: textMain,
                  textMuted: textMuted,
                  isMarathi: isMarathi,
                  onSelectService: _openDetail,
                ),
              ],
            ),
          ),

          // Expand / Collapse Schedule Details
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderCard)),
                color: isDark ? const Color(0xFF1C1514) : const Color(0xFFFAFAF9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded
                        ? (isMarathi ? 'वेळापत्रक लपवा' : 'Hide Full Schedule')
                        : (isMarathi ? 'सर्व प्रस्थान वेळा पहा' : 'View All Departures'),
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.msrtcRed)
                        : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.msrtcRed),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTheme.msrtcRed,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Full Departures List
          if (_isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(14),
              color: isDark ? const Color(0xFF191211) : const Color(0xFFF5F0EB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMarathi ? 'पायरी १: सर्व बसेस' : 'Leg 1: All Departures',
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold, color: textMain)
                        : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.bold, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: route.leg1Services.map((s) {
                      return InkWell(
                        onTap: () => _openDetail(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: surfaceCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderCard),
                          ),
                          child: Text(
                            AppStrings.formatTime(s.validDepartureTime, widget.appState.isMarathi, widget.appState.is24Hour),
                            style: AppTheme.latin(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.msrtcRed,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isMarathi ? 'पायरी २: सर्व बसेस' : 'Leg 2: All Departures',
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold, color: textMain)
                        : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.bold, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: route.leg2Services.map((s) {
                      return InkWell(
                        onTap: () => _openDetail(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: surfaceCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderCard),
                          ),
                          child: Text(
                            AppStrings.formatTime(s.validDepartureTime, widget.appState.isMarathi, widget.appState.is24Hour),
                            style: AppTheme.latin(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.msrtcRed,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegRow({
    required String legNumber,
    required String legNumberEn,
    required String fromStation,
    required String toStation,
    required int busCount,
    required List<BusService> services,
    required bool isDark,
    required Color textMain,
    required Color textMuted,
    required bool isMarathi,
    required ValueChanged<BusService> onSelectService,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.msrtcRed,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isMarathi ? legNumber : legNumberEn,
              style: AppTheme.devanagari(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$fromStation ➔ $toStation',
                      style: isMarathi
                          ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.w700, color: textMain)
                          : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    isMarathi
                        ? '${AppStrings.toDevanagariDigits(busCount.toString(), true)} बसेस'
                        : '$busCount buses',
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)
                        : AppTheme.latin(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Next upcoming departure chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: services.map((s) {
                  return InkWell(
                    onTap: () => onSelectService(s),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2220) : const Color(0xFFF3ECE6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: AppTheme.msrtcRed),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.formatTime(s.validDepartureTime, widget.appState.isMarathi, widget.appState.is24Hour),
                            style: AppTheme.latin(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
