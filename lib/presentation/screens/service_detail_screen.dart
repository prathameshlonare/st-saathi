import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bus_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/app_state.dart';

class ServiceDetailScreen extends StatefulWidget {
  final BusService service;
  final AppState appState;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const ServiceDetailScreen({
    super.key,
    required this.service,
    required this.appState,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late bool _isSaved;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    // The countdown is computed in build(); without this tick it would freeze
    // at the value it had when the screen was opened.
    _countdownTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleToggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSaved = !_isSaved;
    });
    widget.onToggleSave();
  }

  String _getLocalizedType(String type, bool isMr) {
    final lower = type.toLowerCase();
    if (isMr) {
      if (lower.contains('shivneri')) return 'शिवनेरी';
      if (lower.contains('shivshahi')) return 'शिवशाही';
      if (lower.contains('hirkani')) return 'हिरकणी';
      if (lower.contains('sleeper')) return 'शयनयान';
      if (lower.contains('semi') || lower.contains('asiad')) return 'निम-आराम';
      return 'साधी लालपरी';
    } else {
      if (lower.contains('shivneri')) return 'SHIVNERI';
      if (lower.contains('shivshahi')) return 'SHIVSHAHI';
      if (lower.contains('hirkani')) return 'HIRKANI';
      if (lower.contains('sleeper')) return 'SLEEPER';
      if (lower.contains('semi') || lower.contains('asiad')) return 'SEMI-LUXURY';
      return 'ORDINARY';
    }
  }

  void _copyShareDetails(BuildContext context) {
    HapticFeedback.mediumImpact();
    final depDisplay = AppStrings.formatTime(widget.service.validDepartureTime, widget.appState.isMarathi, widget.appState.is24Hour);
    final shareText = widget.appState.isMarathi
        ? 'एसटी साथी वेळापत्रक:\n${widget.service.origin.displayName(true)} ➔ ${widget.service.destination.displayName(true)}\nवेळ: $depDisplay (${widget.service.busType})\n${widget.service.viaStops.isNotEmpty ? "मार्गे: ${widget.service.viaStops}\n" : ""}आगार: ${widget.service.sourceDepot}'
        : 'ST Saathi Timetable:\n${widget.service.origin.displayName(false)} -> ${widget.service.destination.displayName(false)}\nDeparture: ${widget.service.validDepartureTime} (${widget.service.busType})\n${widget.service.viaStops.isNotEmpty ? "Via: ${widget.service.viaStops}\n" : ""}Depot: ${widget.service.sourceDepot}';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.appState.isMarathi
              ? 'वेळापत्रक कॉपी केले! WhatsApp वर पाठवू शकता.'
              : 'Timetable copied! Ready to paste & share.',
          style: widget.appState.isMarathi ? AppTheme.devanagari(fontSize: 13) : AppTheme.latin(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final isMarathi = widget.appState.isMarathi;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viaStops = service.viaList;
    final depDisplay = AppStrings.formatTime(service.validDepartureTime, isMarathi, widget.appState.is24Hour);

    // Calculate relative departure countdown
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final diff = service.depMinutes - currentMinutes;

    String countdownText;
    Color countdownColor;
    if (diff < 0) {
      countdownText = widget.appState.isMarathi ? 'वेळापत्रकानुसार वेळ उलटून गेली आहे' : 'Scheduled time passed today';
      countdownColor = const Color(0xFFB0A8A0);
    } else if (diff <= 5) {
      countdownText = widget.appState.isMarathi ? 'बस आता स्थानकावर सुटत आहे' : 'Departing now from platform';
      countdownColor = const Color(0xFFDC2626);
    } else if (diff <= 60) {
      countdownText = widget.appState.isMarathi
          ? '${AppStrings.toDevanagariDigits(diff.toString(), true)} मिनिटांत सुटेल'
          : 'Leaves in $diff minutes';
      countdownColor = const Color(0xFFD97706);
    } else {
      final h = diff ~/ 60;
      final m = diff % 60;
      countdownText = widget.appState.isMarathi
          ? '${AppStrings.toDevanagariDigits(h.toString(), true)} तास ${AppStrings.toDevanagariDigits(m.toString(), true)} मिनिटांत सुटेल'
          : 'Leaves in ${h}h ${m}m';
      countdownColor = const Color(0xFF2563EB);
    }

    final surfaceCard = isDark ? const Color(0xFF221A19) : Colors.white;
    final borderCard = isDark ? const Color(0xFF382C29) : AppTheme.outline;
    final inkMain = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;
    final inkMuted = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF140E0D) : AppTheme.parchment,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF171211) : AppTheme.parchment,
        foregroundColor: inkMain,
        elevation: 0,
        title: Text(
          AppStrings.get('app_title', widget.appState.isMarathi),
          style: widget.appState.isMarathi
              ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.w700, color: inkMain)
              : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.w700, color: inkMain),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: widget.appState.isMarathi ? 'वेळापत्रक पाठवा' : 'Share Schedule',
            onPressed: () => _copyShareDetails(context),
          ),
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSaved ? AppTheme.msrtcGold : inkMain,
            ),
            onPressed: _handleToggle,
            tooltip: _isSaved ? AppStrings.get('remove_saved', widget.appState.isMarathi) : AppStrings.get('save_service', widget.appState.isMarathi),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Enamel Destination Board ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCard, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.destination.displayName(isMarathi),
                              style: isMarathi
                                  ? AppTheme.devanagari(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: inkMain,
                                    )
                                  : AppTheme.latin(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: inkMain,
                                    ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              service.destination.secondaryName(isMarathi).toUpperCase(),
                              style: !isMarathi
                                  ? AppTheme.devanagari(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: inkMuted,
                                    )
                                  : AppTheme.latin(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: inkMuted,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.msrtcRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.msrtcRed.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          _getLocalizedType(service.busType, isMarathi),
                          style: isMarathi
                              ? AppTheme.devanagari(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.msrtcRed,
                                )
                              : AppTheme.latin(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.msrtcRed,
                                  letterSpacing: 0.5,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        service.origin.displayName(isMarathi),
                        style: isMarathi
                            ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.w600, color: inkMuted)
                            : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.w600, color: inkMuted),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: inkMuted),
                      const SizedBox(width: 6),
                      Text(
                        service.destination.displayName(isMarathi),
                        style: isMarathi
                            ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.w600, color: inkMuted)
                            : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.w600, color: inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // --- Departure Time & Live Countdown Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCard),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.msrtcRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule_rounded, color: AppTheme.msrtcRed, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('departure', isMarathi),
                              style: isMarathi
                                  ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold, color: inkMuted)
                                  : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w600, color: inkMuted),
                            ),
                            Text(
                              depDisplay,
                              style: isMarathi
                                  ? AppTheme.devanagari(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.msrtcRed,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    )
                                  : AppTheme.latin(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.msrtcRed,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Countdown pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: countdownColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: countdownColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: countdownColor),
                        const SizedBox(width: 8),
                        Text(
                          countdownText,
                          style: isMarathi
                              ? AppTheme.devanagari(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: countdownColor,
                                )
                              : AppTheme.latin(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: countdownColor,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // --- Route Timeline Card ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded, size: 18, color: AppTheme.msrtcRed),
                      const SizedBox(width: 8),
                      Text(
                        (isMarathi ? 'मार्ग व थांबे' : 'Route & Stops Sequence').toUpperCase(),
                        style: isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: inkMain,
                              )
                            : AppTheme.latin(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: inkMain,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Origin Stop
                  _buildStopNode(
                    title: service.origin.displayName(isMarathi),
                    subtitle: service.sourceDepot,
                    isFirst: true,
                    isLast: false,
                    isDepot: true,
                    isDark: isDark,
                    isMarathi: isMarathi,
                  ),

                  // Intermediate Via Stops
                  for (int i = 0; i < viaStops.length; i++)
                    _buildStopNode(
                      title: viaStops[i],
                      subtitle: '${AppStrings.get('via', isMarathi)} #${i + 1}',
                      isFirst: false,
                      isLast: false,
                      isDepot: false,
                      isDark: isDark,
                      isMarathi: isMarathi,
                    ),

                  // Destination Stop
                  _buildStopNode(
                    title: service.destination.displayName(isMarathi),
                    subtitle: isMarathi ? 'अंतिम गंतव्य स्थानक' : 'Final Destination',
                    isFirst: false,
                    isLast: true,
                    isDepot: service.destination.isDepot,
                    isDark: isDark,
                    isMarathi: isMarathi,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // --- Data Provenance & Trust Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.msrtcGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.msrtcGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: AppTheme.msrtcGoldDark, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.get('data_info', isMarathi),
                        style: isMarathi
                            ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.msrtcGoldDark)
                            : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.msrtcGoldDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isMarathi ? "माहिती स्रोत" : "Source"}: ${service.sourceDepot}',
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF44403C))
                        : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF44403C)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.get('disclaimer', isMarathi),
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 12, color: inkMuted)
                        : AppTheme.latin(fontSize: 11, color: inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: surfaceCard,
          border: Border(
            top: BorderSide(
              color: borderCard,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyShareDetails(context),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  isMarathi ? 'पाठवा' : 'Share',
                  style: isMarathi
                      ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold)
                      : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.msrtcRed,
                  side: const BorderSide(color: AppTheme.msrtcRed, width: 1.2),
                  minimumSize: const Size(96, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleToggle,
                  icon: Icon(
                    _isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                    size: 20,
                  ),
                  label: Text(
                    _isSaved
                        ? (isMarathi ? 'जतन केले' : 'Saved')
                        : (isMarathi ? 'फेरी जतन करा' : 'Bookmark Service'),
                    style: isMarathi
                        ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold)
                        : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved ? AppTheme.msrtcGoldDark : AppTheme.msrtcRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopNode({
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    required bool isDepot,
    required bool isDark,
    required bool isMarathi,
  }) {
    final nodeColor = isFirst
        ? AppTheme.msrtcRed
        : (isLast ? AppTheme.msrtcGoldDark : const Color(0xFFB0A8A0));

    // A Stack instead of IntrinsicHeight: the old Row needed a double layout
    // pass per stop, which stuttered on routes with 30+ stops. The rail line
    // and dot are positioned absolutely; the text sizes the row naturally.
    return Stack(
      children: [
        // Connecting line above the dot (every stop except the first)
        if (!isFirst)
          Positioned(
            left: 11,
            top: 0,
            height: 8,
            child: Container(width: 2, color: const Color(0xFFD6D3D1)),
          ),
        // Connecting line below the dot (every stop except the last)
        if (!isLast)
          Positioned(
            left: 11,
            top: 22,
            bottom: 0,
            child: Container(width: 2, color: const Color(0xFFD6D3D1)),
          ),
        // Stop dot
        Positioned(
          left: 5,
          top: 8,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? const Color(0xFF221E1C) : Colors.white, width: 2),
            ),
          ),
        ),
        // Stop Name & Subtitle, offset past the 24px rail + 14px gap
        Padding(
          padding: const EdgeInsets.only(left: 38, bottom: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: isMarathi
                          ? AppTheme.devanagari(
                              fontSize: 16,
                              fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1C1917),
                            )
                          : AppTheme.latin(
                              fontSize: 15,
                              fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1C1917),
                            ),
                    ),
                  ),
                  if (isDepot) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isFirst ? AppTheme.msrtcRed : AppTheme.msrtcGoldDark).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isFirst ? AppTheme.msrtcRed : AppTheme.msrtcGoldDark).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isMarathi ? 'आगार' : 'DEPOT',
                        style: isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isFirst ? AppTheme.msrtcRed : AppTheme.msrtcGoldDark,
                              )
                            : AppTheme.latin(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isFirst ? AppTheme.msrtcRed : AppTheme.msrtcGoldDark,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: isMarathi
                    ? AppTheme.devanagari(
                        fontSize: 12,
                        color: const Color(0xFFB0A8A0),
                      )
                    : AppTheme.latin(
                        fontSize: 11,
                        color: const Color(0xFFB0A8A0),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
