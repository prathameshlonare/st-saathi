import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database_helper.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/station.dart';
import 'station_picker_sheet.dart';

class FirstLaunchSetupSheet extends StatefulWidget {
  final bool initialMarathi;
  final Station? initialOrigin;
  final ValueChanged<bool> onLanguageChanged;
  final Future<void> Function(Station station, bool isMarathi) onComplete;

  const FirstLaunchSetupSheet({
    super.key,
    required this.initialMarathi,
    this.initialOrigin,
    required this.onLanguageChanged,
    required this.onComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required bool initialMarathi,
    Station? initialOrigin,
    required ValueChanged<bool> onLanguageChanged,
    required Future<void> Function(Station station, bool isMarathi) onComplete,
    bool isDismissible = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => FirstLaunchSetupSheet(
        initialMarathi: initialMarathi,
        initialOrigin: initialOrigin,
        onLanguageChanged: onLanguageChanged,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<FirstLaunchSetupSheet> createState() => _FirstLaunchSetupSheetState();
}

class _FirstLaunchSetupSheetState extends State<FirstLaunchSetupSheet> {
  late bool _isMarathi;
  Station? _selectedStation;
  List<Station> _quickDepots = [];
  bool _loading = true;
  bool _loadError = false;

  final List<String> _priorityDepotNames = [
    'Amravati',
    'Pune Swargate',
    'Nashik',
    'Chhatrapati Sambhajinagar',
    'Akola',
    'Nagpur',
    'Thane',
    'Kolhapur',
    'Solapur',
    'Chandrapur',
  ];

  @override
  void initState() {
    super.initState();
    _isMarathi = widget.initialMarathi;
    _selectedStation = widget.initialOrigin;
    _loadDepots();
  }

  Future<void> _loadDepots() async {
    final List<Station> foundDepots = [];
    Object? firstError;

    // Query priority hubs. Each query is guarded so one failure cannot
    // strand the whole sheet on a spinner with a dead Get Started button.
    for (final name in _priorityDepotNames) {
      try {
        final res = await DatabaseHelper.instance.searchStations(name, limit: 1);
        if (res.isNotEmpty) {
          foundDepots.add(res.first);
        }
      } catch (e) {
        firstError ??= e;
      }
    }

    // Default to the first found depot if none provided
    if (_selectedStation == null && foundDepots.isNotEmpty) {
      _selectedStation = foundDepots.first;
    }

    if (mounted) {
      setState(() {
        _quickDepots = foundDepots;
        _loading = false;
        _loadError = foundDepots.isEmpty && firstError != null;
      });
    }
  }

  void _retryLoad() {
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _loadDepots();
  }

  Widget _buildDepotLoadError({
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261D1B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.msrtcRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.msrtcRed, size: 28),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('setup_load_failed', _isMarathi),
            textAlign: TextAlign.center,
            style: _isMarathi
                ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.w600, color: textMain)
                : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _retryLoad,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              AppStrings.get('retry', _isMarathi),
              style: _isMarathi
                  ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.w700)
                  : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(foregroundColor: AppTheme.msrtcRed),
          ),
        ],
      ),
    );
  }

  void _onToggleLanguage(bool marathi) {
    HapticFeedback.selectionClick();
    setState(() => _isMarathi = marathi);
    widget.onLanguageChanged(marathi);
  }

  void _onSelectDepot(Station station) {
    HapticFeedback.selectionClick();
    setState(() => _selectedStation = station);
  }

  Future<void> _openCustomDepotPicker() async {
    HapticFeedback.lightImpact();
    final station = await StationPickerSheet.show(
      context,
      title: AppStrings.get('select_home_depot', _isMarathi),
      isMarathi: _isMarathi,
    );

    if (station != null && mounted) {
      setState(() => _selectedStation = station);
    }
  }

  Future<void> _saveAndComplete() async {
    if (_selectedStation == null) return;

    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch_done', true);
    await prefs.setBool('is_marathi', _isMarathi);
    await prefs.setInt('default_origin_id', _selectedStation!.id);
    await prefs.setString('default_origin_name_en', _selectedStation!.nameEn);
    await prefs.setString('default_origin_name_mr', _selectedStation!.nameMr);

    if (mounted) {
      Navigator.of(context).pop();
      await widget.onComplete(_selectedStation!, _isMarathi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1413) : const Color(0xFFFAF7F4);
    final cardBg = isDark ? const Color(0xFF261D1B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3D302D) : const Color(0xFFE6DDD8);
    final textMain = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;
    final textMuted = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MD3 Drag / Anchor Pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFB5ABA7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- MSRTC HERITAGE EMBLEM & WELCOME BANNER ---
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.msrtcRed,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.msrtcRed.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      AppStrings.get('welcome_title', _isMarathi),
                      textAlign: TextAlign.center,
                      style: _isMarathi
                          ? AppTheme.devanagari(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            )
                          : AppTheme.latin(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      AppStrings.get('welcome_subtitle', _isMarathi),
                      textAlign: TextAlign.center,
                      style: _isMarathi
                          ? AppTheme.devanagari(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            )
                          : AppTheme.latin(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- SECTION 1: LANGUAGE SELECTION ---
                  Row(
                    children: [
                      Icon(Icons.translate_rounded, size: 16, color: AppTheme.msrtcRed),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.get('language', _isMarathi),
                        style: _isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.msrtcRed,
                              )
                            : AppTheme.latin(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.msrtcRed,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Marathi Option Card
                      Expanded(
                        child: _LanguageOptionCard(
                          title: 'मराठी',
                          subtitle: 'देवनागरी अंक व स्थानक नावे',
                          isSelected: _isMarathi,
                          isDark: isDark,
                          onTap: () => _onToggleLanguage(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // English Option Card
                      Expanded(
                        child: _LanguageOptionCard(
                          title: 'English',
                          subtitle: 'Standard English & Numerals',
                          isSelected: !_isMarathi,
                          isDark: isDark,
                          onTap: () => _onToggleLanguage(false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // --- SECTION 2: DEFAULT DEPARTURE DEPOT ---
                  Row(
                    children: [
                      Icon(Icons.home_work_rounded, size: 16, color: AppTheme.msrtcRed),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.get('home_depot', _isMarathi),
                        style: _isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.msrtcRed,
                              )
                            : AppTheme.latin(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.msrtcRed,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.get('home_depot_desc', _isMarathi),
                    style: _isMarathi
                        ? AppTheme.devanagari(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          )
                        : AppTheme.latin(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                  ),

                  const SizedBox(height: 10),

                  // Active Selected Depot Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.msrtcRed.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.msrtcRed.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.msrtcRed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.msrtcRed,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStation != null
                                    ? _selectedStation!.displayName(_isMarathi)
                                    : AppStrings.get('select_origin', _isMarathi),
                                style: _isMarathi
                                    ? AppTheme.devanagari(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textMain,
                                      )
                                    : AppTheme.latin(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: textMain,
                                      ),
                              ),
                              if (_selectedStation != null)
                                Text(
                                  _selectedStation!.secondaryName(_isMarathi),
                                  style: AppTheme.latin(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.get('home_badge', _isMarathi),
                                style: _isMarathi
                                    ? AppTheme.devanagari(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF15803D),
                                      )
                                    : AppTheme.latin(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF15803D),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Popular Depot Chips
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.msrtcRed),
                      ),
                    )
                  else if (_loadError)
                    _buildDepotLoadError(isDark: isDark, textMain: textMain, textMuted: textMuted)
                  else ...[
                    Text(
                      AppStrings.get('popular_depots', _isMarathi),
                      style: _isMarathi
                          ? AppTheme.devanagari(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                            )
                          : AppTheme.latin(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickDepots.map((depot) {
                        final isChosen = _selectedStation?.id == depot.id;
                        return ChoiceChip(
                          label: Text(
                            depot.displayName(_isMarathi),
                            style: _isMarathi
                                ? AppTheme.devanagari(
                                    fontSize: 13,
                                    fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                                    color: isChosen ? Colors.white : textMain,
                                  )
                                : AppTheme.latin(
                                    fontSize: 12,
                                    fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                                    color: isChosen ? Colors.white : textMain,
                                  ),
                          ),
                          selected: isChosen,
                          selectedColor: AppTheme.msrtcRed,
                          backgroundColor: cardBg,
                          side: BorderSide(
                            color: isChosen ? AppTheme.msrtcRed : cardBorder,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onSelected: (_) => _onSelectDepot(depot),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Search all 1,000+ stations button
                  OutlinedButton.icon(
                    onPressed: _openCustomDepotPicker,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      AppStrings.get('search_all_depots', _isMarathi),
                      style: _isMarathi
                          ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold)
                          : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.msrtcRed,
                      side: BorderSide(color: AppTheme.msrtcRed.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // --- BOTTOM FIXED CTA BUTTON ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(
                top: BorderSide(color: cardBorder, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selectedStation != null ? _saveAndComplete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.msrtcRed,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.get('get_started', _isMarathi),
                          style: _isMarathi
                              ? AppTheme.devanagari(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                )
                              : AppTheme.latin(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                // Why is the button greyed out? Tell the user.
                if (_selectedStation == null && !_loading && !_loadError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppStrings.get('pick_a_depot_first', _isMarathi),
                      textAlign: TextAlign.center,
                      style: _isMarathi
                          ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)
                          : AppTheme.latin(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _LanguageOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = AppTheme.msrtcRed.withValues(alpha: isDark ? 0.20 : 0.08);
    final inactiveBg = isDark ? const Color(0xFF261D1B) : Colors.white;
    final activeBorder = AppTheme.msrtcRed;
    final inactiveBorder = isDark ? const Color(0xFF3D302D) : const Color(0xFFE6DDD8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.devanagari(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppTheme.msrtcRed
                          : (isDark ? Colors.white : AppTheme.inkPrimary),
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected ? AppTheme.msrtcRed : const Color(0xFFA8A29E),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.devanagari(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary,
              ),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }
}
