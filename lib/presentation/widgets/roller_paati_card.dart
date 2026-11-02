import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bus_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';

/// The Mechanical Roller-Blind Destination Paati (रोलर पाटी)
///
/// Authentic MSRTC physical cloth spool that rolls along the X-axis over top
/// and bottom cylindrical rollers. Hardware-accelerated with zero dynamic blur shadows.
class RollerPaatiCard extends StatefulWidget {
  final List<BusService> services;
  final bool isMarathi;
  final bool is24Hour;
  final ValueChanged<BusService>? onSelectService;
  final bool isLoading;

  const RollerPaatiCard({
    super.key,
    required this.services,
    required this.isMarathi,
    required this.is24Hour,
    this.onSelectService,
    this.isLoading = false,
  });

  @override
  State<RollerPaatiCard> createState() => _RollerPaatiCardState();
}

class _RollerPaatiCardState extends State<RollerPaatiCard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _flipForward = true;
  late AnimationController _rollAnimCtrl;
  late Animation<double> _curvedAnim;

  // Refreshes only this card's countdown badge ("DEPARTING NOW", "IN 12M", …).
  // Runs on its own short cadence so the whole page does not need to rebuild.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _rollAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _curvedAnim = CurvedAnimation(
      parent: _rollAnimCtrl,
      curve: Curves.easeInOutCubic,
    );
    _rollAnimCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.selectionClick();
      }
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(RollerPaatiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.services.length != oldWidget.services.length) {
      if (_currentIndex >= widget.services.length) {
        _currentIndex = math.max(0, widget.services.length - 1);
      }
      if (_previousIndex >= widget.services.length) {
        _previousIndex = math.max(0, widget.services.length - 1);
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rollAnimCtrl.dispose();
    super.dispose();
  }

  void _crankNext() {
    if (widget.services.isEmpty || _rollAnimCtrl.isAnimating) return;
    HapticFeedback.lightImpact();
    setState(() {
      _flipForward = true;
      _previousIndex = _currentIndex;
      _currentIndex = (_currentIndex + 1) % widget.services.length;
    });
    _rollAnimCtrl.forward(from: 0.0);
  }

  void _crankPrev() {
    if (widget.services.isEmpty || _rollAnimCtrl.isAnimating) return;
    HapticFeedback.lightImpact();
    setState(() {
      _flipForward = false;
      _previousIndex = _currentIndex;
      _currentIndex = (_currentIndex - 1 + widget.services.length) % widget.services.length;
    });
    _rollAnimCtrl.forward(from: 0.0);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasServices = widget.services.isNotEmpty;
    final currentService = hasServices ? widget.services[_currentIndex % widget.services.length] : null;

    // Windshield frame tokens
    final frameBg = isDark ? const Color(0xFF1C1514) : const Color(0xFF261D1B);
    final spoolBg = isDark ? const Color(0xFF2B211F) : const Color(0xFFFBF8F3);
    final textDestColor = isDark ? const Color(0xFFFAF6F2) : const Color(0xFF1C1716);
    final textMutedColor = isDark ? const Color(0xFFA69B97) : const Color(0xFF6B605C);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -100) {
                _crankNext();
              } else if (details.primaryVelocity! > 100) {
                _crankPrev();
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: frameBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF382B28) : const Color(0xFF453633),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Metal Rail with Brass Rivets & Paati Badge
                  Row(
                    children: [
                      // Left Rivet
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Header Text
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              widget.isMarathi ? 'म.रा.मा.प. महामंडळ' : 'MSRTC • DIVISION 04',
                              style: AppTheme.latin(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD4C8C0),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4AF37),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isMarathi ? 'मार्ग फलक (रोलर पाटी)' : 'ROUTE PAATI',
                              style: AppTheme.devanagari(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFBBF24),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Rivet
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Mechanical 3D Cylindrical Roll Window (X-Axis Rotation)
                  InkWell(
                    onTap: () {
                      if (currentService != null && widget.onSelectService != null) {
                        widget.onSelectService!(currentService);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: spoolBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF423430) : const Color(0xFFDDD5CA),
                            width: 1.0,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // 3D Physical Cloth Rolling along X-Axis
                            if (hasServices)
                              AnimatedBuilder(
                                animation: _curvedAnim,
                                builder: (context, _) {
                                  final t = _curvedAnim.value;
                                  final bool isFirstHalf = t < 0.5;

                                  final displayedService = isFirstHalf
                                      ? widget.services[_previousIndex % widget.services.length]
                                      : widget.services[_currentIndex % widget.services.length];

                                  // Cylindrical Roll Physics:
                                  // As the cloth rolls around the top/bottom horizontal cylinders (X-axis):
                                  // Outgoing curves back & up: rotateX(0 -> +pi/2.2), translateY(0 -> -60)
                                  // Incoming curves in & up: rotateX(-pi/2.2 -> 0), translateY(+60 -> 0)
                                  final double transY;
                                  final double rotX;
                                  final double opacity;
                                  final dir = _flipForward ? 1.0 : -1.0;

                                  if (isFirstHalf) {
                                    final progress = t * 2.0; // 0.0 to 1.0
                                    transY = -progress * 60.0 * dir;
                                    rotX = progress * (math.pi / 2.3) * dir;
                                    opacity = (1.0 - progress * 0.7).clamp(0.0, 1.0);
                                  } else {
                                    final progress = (t - 0.5) * 2.0; // 0.0 to 1.0
                                    transY = (1.0 - progress) * 60.0 * dir;
                                    rotX = -(1.0 - progress) * (math.pi / 2.3) * dir;
                                    opacity = (0.3 + progress * 0.7).clamp(0.0, 1.0);
                                  }

                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.0018) // Physical optical depth
                                      ..setTranslationRaw(0.0, transY, 0.0)
                                      ..rotateX(rotX),
                                    alignment: Alignment.center,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: _buildPaatiSpoolContent(
                                          service: displayedService,
                                          isMarathi: widget.isMarathi,
                                          textColor: textDestColor,
                                          textMuted: textMutedColor,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            else if (widget.isLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.msrtcGold,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: _buildEmptySpoolContent(
                                  isMarathi: widget.isMarathi,
                                  textColor: textDestColor,
                                  textMuted: textMutedColor,
                                ),
                              ),

                            // Static Cylindrical Spool Shadow Overlays (zero dynamic blur cost)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                                      ],
                                      stops: const [0.0, 0.18, 0.82, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Bottom Crank Control Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Queue indicator dots
                      if (hasServices)
                        Row(
                          children: [
                            for (int i = 0; i < math.min(widget.services.length, 6); i++)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: i == _currentIndex ? 16 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i == _currentIndex
                                      ? const Color(0xFFFBBF24)
                                      : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isMarathi
                                  ? 'फेरी ${AppStrings.toDevanagariDigits((_currentIndex + 1).toString(), true)}/${AppStrings.toDevanagariDigits(widget.services.length.toString(), true)}'
                                  : 'BUS ${_currentIndex + 1}/${widget.services.length}',
                              style: AppTheme.latin(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD4C8C0),
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),

                      // Tactile Brass "Crank Paati" Button
                      InkWell(
                        onTap: _crankNext,
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A).withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RotationTransition(
                                    turns: _curvedAnim,
                                    child: const Icon(
                                      Icons.rotate_right_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isMarathi ? 'पाटी फिरवा' : 'Crank Paati',
                                    style: widget.isMarathi
                                        ? AppTheme.devanagari(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          )
                                        : AppTheme.latin(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaatiSpoolContent({
    required BusService service,
    required bool isMarathi,
    required Color textColor,
    required Color textMuted,
    required bool isDark,
  }) {
    final typeColor = _getBusTypeColor(service.busType);
    final typeLabel = _getLocalizedBusType(service.busType, isMarathi);

    // Dynamic countdown
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final diff = service.depMinutes - currentMinutes;

    String countdownBadge;
    Color countdownBg;
    Color countdownText;

    if (diff < 0) {
      countdownBadge = isMarathi ? 'वेळ उलटली' : 'DEPARTED';
      countdownBg = const Color(0xFF78716C).withValues(alpha: 0.15);
      countdownText = const Color(0xFFB0A8A0);
    } else if (diff <= 5) {
      countdownBadge = isMarathi ? 'आताच सुटत आहे' : 'DEPARTING NOW';
      countdownBg = const Color(0xFFDC2626).withValues(alpha: 0.15);
      countdownText = const Color(0xFFDC2626);
    } else if (diff <= 60) {
      countdownBadge = isMarathi
          ? '${AppStrings.toDevanagariDigits(diff.toString(), true)} मिनिटांत'
          : 'IN ${diff}M';
      countdownBg = const Color(0xFFD97706).withValues(alpha: 0.15);
      countdownText = const Color(0xFFB45309);
    } else {
      final h = diff ~/ 60;
      final m = diff % 60;
      countdownBadge = isMarathi
          ? '${AppStrings.toDevanagariDigits(h.toString(), true)}तास ${AppStrings.toDevanagariDigits(m.toString(), true)}मि'
          : 'IN ${h}H ${m}M';
      countdownBg = const Color(0xFF2563EB).withValues(alpha: 0.12);
      countdownText = const Color(0xFF1D4ED8);
    }

    final primaryDest = isMarathi
        ? service.destination.displayName(true)
        : service.destination.displayName(false).toUpperCase();
    final secondaryDest = isMarathi
        ? service.destination.secondaryName(true).toUpperCase()
        : service.destination.secondaryName(false);

    final depTimeFormatted = AppStrings.formatTime(service.validDepartureTime, isMarathi, widget.is24Hour);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badges: Bus Type & Countdown Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bus Type Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeLabel,
                style: isMarathi
                    ? AppTheme.devanagari(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      )
                    : AppTheme.latin(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
              ),
            ),

            // Tabular Time & Countdown
            Row(
              children: [
                Text(
                  depTimeFormatted,
                  style: AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: countdownBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    countdownBadge,
                    style: AppTheme.devanagari(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: countdownText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Main Destination Stencil Typography
        Center(
          child: Column(
            children: [
              Text(
                primaryDest,
                style: isMarathi
                    ? AppTheme.devanagari(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.15,
                      )
                    : AppTheme.latin(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 0.6,
                        height: 1.15,
                      ),
                textAlign: TextAlign.center,
                maxLines: null,
              ),
              const SizedBox(height: 1),
              Text(
                secondaryDest,
                style: isMarathi
                    ? AppTheme.devanagari(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      )
                    : AppTheme.latin(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.4,
                      ),
                textAlign: TextAlign.center,
                maxLines: null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Route Via Summary
        Text(
          service.viaStops.isNotEmpty
              ? (isMarathi
                  ? 'मार्गे: ${service.viaStops.replaceAll(',', ' • ')}'
                  : 'Via: ${service.viaStops.replaceAll(',', ' • ')}')
              : (isMarathi ? 'थेट जलद सेवा • विनाथांबा' : 'Direct Non-Stop Express'),
          style: isMarathi
              ? AppTheme.devanagari(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                )
              : AppTheme.latin(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
          textAlign: TextAlign.center,
          maxLines: null,
        ),
      ],
    );
  }

  Widget _buildEmptySpoolContent({
    required bool isMarathi,
    required Color textColor,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(Icons.directions_bus_outlined, size: 28, color: textMuted),
          const SizedBox(height: 6),
          Text(
            isMarathi ? 'सध्या कोणतीही फेरी उपलब्ध नाही' : 'No upcoming departures scheduled',
            style: isMarathi
                ? AppTheme.devanagari(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  )
                : AppTheme.latin(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
          ),
          Text(
            isMarathi ? 'दुसरे प्रस्थान आगार निवडून वेळापत्रक शोधा' : 'Select another depot or search routes below',
            style: isMarathi
                ? AppTheme.devanagari(
                    fontSize: 12,
                    color: textMuted,
                  )
                : AppTheme.latin(
                    fontSize: 11,
                    color: textMuted,
                  ),
          ),
        ],
      ),
    );
  }
}
