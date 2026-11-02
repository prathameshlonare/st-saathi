import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/station.dart';
import '../../models/bus_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/app_state.dart';
import '../widgets/station_picker_sheet.dart';
import '../widgets/enamel_bus_card.dart';
import '../widgets/roller_paati_card.dart';
import 'search_results_screen.dart';
import 'service_detail_screen.dart';

class HomeSearchScreen extends StatefulWidget {
  final AppState appState;
  final ValueChanged<bool> onLanguageToggle;
  final Station? defaultOrigin;
  final ValueChanged<Station>? onDefaultOriginChanged;
  final bool isActive;

  const HomeSearchScreen({
    super.key,
    required this.appState,
    required this.onLanguageToggle,
    this.defaultOrigin,
    this.onDefaultOriginChanged,
    this.isActive = true,
  });

  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Station? _origin;
  Station? _destination;
  List<Map<String, dynamic>> _recentSearches = [];
  List<BusService> _upcomingDepartures = [];
  Set<int> _savedServiceIds = {};
  bool _departuresLoaded = false;

  late AnimationController _swapAnimCtrl;
  late Animation<double> _swapRotateAnim;

  List<Map<String, dynamic>> _frequentDestinations = [];

  @override
  void initState() {
    super.initState();
    _swapAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _swapRotateAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _swapAnimCtrl, curve: Curves.easeOutBack),
    );
    _loadRecentSearches();
    _loadSavedIds();
    _setDefaultOrigin();
  }

  @override
  void didUpdateWidget(covariant HomeSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defaultOrigin != null &&
        widget.defaultOrigin?.id != oldWidget.defaultOrigin?.id) {
      setState(() => _origin = widget.defaultOrigin);
      _loadUpcomingDepartures(widget.defaultOrigin!.id);
    }
  }

  @override
  void dispose() {
    _swapAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _setDefaultOrigin() async {
    if (widget.defaultOrigin != null) {
      if (mounted) {
        setState(() => _origin = widget.defaultOrigin);
        _loadUpcomingDepartures(widget.defaultOrigin!.id);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedOriginId = prefs.getInt('default_origin_id');
    Station? targetOrigin;

    if (savedOriginId != null) {
      targetOrigin = await DatabaseHelper.instance.getStationById(savedOriginId);
    }

    if (targetOrigin == null) {
      final defaultList = await DatabaseHelper.instance.searchStations('Amravati', limit: 1);
      if (defaultList.isNotEmpty) {
        targetOrigin = defaultList.first;
      }
    }

    if (targetOrigin != null && mounted) {
      setState(() => _origin = targetOrigin);
      _loadUpcomingDepartures(targetOrigin.id);
    }
  }

  bool _isHomeDepot() {
    if (_origin == null) return false;
    if (widget.defaultOrigin != null) {
      return _origin!.id == widget.defaultOrigin!.id;
    }
    return false;
  }

  void _offerSetAsHome(Station st) {
    if (widget.defaultOrigin?.id == st.id) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.appState.isMarathi
              ? '${st.displayName(true)} मुख्य आगार म्हणून सेट करायचे का?'
              : 'Set ${st.displayName(false)} as default home depot?',
          style: widget.appState.isMarathi
              ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.w600)
              : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: AppStrings.get('set_as_home', widget.appState.isMarathi),
          textColor: AppTheme.msrtcGold,
          onPressed: () {
            widget.onDefaultOriginChanged?.call(st);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${st.displayName(widget.appState.isMarathi)} ${AppStrings.get('depot_saved_toast', widget.appState.isMarathi)}',
                  style: widget.appState.isMarathi
                      ? AppTheme.devanagari(fontSize: 13)
                      : AppTheme.latin(fontSize: 13),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadUpcomingDepartures(int originId) async {
    try {
      final upcoming = await DatabaseHelper.instance.getUpcomingServicesFromOrigin(originId, limit: 5);
      final frequent = await DatabaseHelper.instance.getFrequentDestinationsFromOrigin(originId, limit: 10);
      if (mounted) {
        setState(() {
          _upcomingDepartures = upcoming;
          _frequentDestinations = frequent;
          _departuresLoaded = true;
        });
      }
    } catch (_) {
      // A failed read must not leave the hero card stuck on a spinner.
      if (mounted) {
        setState(() {
          _upcomingDepartures = [];
          _frequentDestinations = [];
          _departuresLoaded = true;
        });
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('recent_searches') ?? [];
    final List<Map<String, dynamic>> loaded = [];

    for (final item in rawList) {
      final parts = item.split('|');
      if (parts.length >= 6) {
        loaded.add({
          'o_id': int.tryParse(parts[0]) ?? 0,
          'o_name_en': parts[1],
          'o_name_mr': parts[2],
          'd_id': int.tryParse(parts[3]) ?? 0,
          'd_name_en': parts[4],
          'd_name_mr': parts[5],
        });
      } else if (parts.length >= 4) {
        // Legacy 4-part entry stored a single name; reuse it for both languages.
        loaded.add({
          'o_id': int.tryParse(parts[0]) ?? 0,
          'o_name_en': parts[1],
          'o_name_mr': parts[1],
          'd_id': int.tryParse(parts[2]) ?? 0,
          'd_name_en': parts[3],
          'd_name_mr': parts[3],
        });
      }
    }

    if (mounted) {
      setState(() => _recentSearches = loaded.take(4).toList());
    }
  }

  Future<void> _saveRecentSearch(Station origin, Station destination) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('recent_searches') ?? [];
    // Store both language names so history reads correctly after a switch.
    final key = '${origin.id}|${origin.nameEn}|${origin.nameMr}|${destination.id}|${destination.nameEn}|${destination.nameMr}';
    
    rawList.remove(key);
    rawList.insert(0, key);
    
    await prefs.setStringList('recent_searches', rawList.take(8).toList());
    _loadRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    if (mounted) setState(() => _recentSearches = []);
  }

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_bus_ids') ?? [];
    if (mounted) {
      setState(() {
        _savedServiceIds = list.map((e) => int.tryParse(e) ?? 0).toSet();
      });
    }
  }

  Future<void> _toggleSave(BusService service) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_bus_ids') ?? [];
    final idStr = service.id.toString();

    bool added = false;
    if (list.contains(idStr)) {
      list.remove(idStr);
      _savedServiceIds.remove(service.id);
    } else {
      list.add(idStr);
      _savedServiceIds.add(service.id);
      added = true;
    }

    await prefs.setStringList('saved_bus_ids', list);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? AppStrings.get('saved_service', widget.appState.isMarathi)
                : AppStrings.get('remove_saved', widget.appState.isMarathi),
            style: widget.appState.isMarathi ? AppTheme.devanagari(fontSize: 14) : AppTheme.latin(fontSize: 13),
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _swapStations() {
    HapticFeedback.lightImpact();
    _swapAnimCtrl.forward(from: 0.0);
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
    if (_origin != null) {
      _loadUpcomingDepartures(_origin!.id);
    }
  }

  void _executeSearch() {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.isMarathi
                ? 'कृपया प्रस्थान व गंतव्य स्थानक दोन्ही निवडा'
                : 'Please select both departure and destination stations',
            style: AppTheme.devanagari(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.msrtcRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_origin!.id == _destination!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.isMarathi
                ? 'प्रस्थान व गंतव्य स्थानक वेगवेगळे असावे'
                : 'Origin and destination cannot be the same',
            style: AppTheme.devanagari(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.msrtcRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    _saveRecentSearch(_origin!, _destination!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          origin: _origin!,
          destination: _destination!,
          appState: widget.appState,
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(BusService service) async {
    final isSaved = _savedServiceIds.contains(service.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          service: service,
          appState: widget.appState,
          isSaved: isSaved,
          onToggleSave: () => _toggleSave(service),
        ),
      ),
    );
    if (mounted) _loadSavedIds();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette tokens
    final parchmentBg = isDark ? const Color(0xFF140E0D) : AppTheme.parchment;
    final surfaceContainer = isDark ? const Color(0xFF221A19) : Colors.white;
    final outlineBorder = isDark ? const Color(0xFF382C29) : AppTheme.outline;
    final textMuted = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;
    final textMain = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;

    return Scaffold(
      backgroundColor: parchmentBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.msrtcRed,
          onRefresh: () async {
            if (_origin != null) {
              await _loadUpcomingDepartures(_origin!.id);
            }
            await _loadRecentSearches();
            await _loadSavedIds();
          },
          child: CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
              // --- SEAMLESS APP HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    // App Title & Tagline
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppStrings.get('app_title', widget.appState.isMarathi),
                                style: widget.appState.isMarathi
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
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF15803D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.appState.isMarathi
                                ? 'महाराष्ट्र एसटी वेळापत्रक • १००% ऑफलाईन'
                                : 'MAHARASHTRA ST TIMETABLE • 100% OFFLINE',
                            style: AppTheme.latin(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.msrtcGoldDark,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Language Switcher Pill
                    InkWell(
                      onTap: () => widget.onLanguageToggle(!widget.appState.isMarathi),
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E2220) : AppTheme.surfaceMid,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: outlineBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.translate_rounded, size: 14, color: AppTheme.msrtcRed),
                                const SizedBox(width: 5),
                                Text(
                                  widget.appState.isMarathi ? 'English' : 'मराठी',
                                  style: widget.appState.isMarathi
                                      ? AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)
                                      : AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // --- ACTIVE DEPOT ANCHOR STRIP ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1615) : AppTheme.surfaceMid,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: outlineBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: AppTheme.msrtcRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.appState.isMarathi ? 'सध्याचे आगार' : 'Departure Depot',
                                style: AppTheme.devanagari(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              if (_isHomeDepot()) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    AppStrings.get('home_badge', widget.appState.isMarathi),
                                    style: widget.appState.isMarathi
                                        ? AppTheme.devanagari(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF15803D),
                                          )
                                        : AppTheme.latin(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF15803D),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _origin != null
                                ? _origin!.displayName(widget.appState.isMarathi)
                                : (widget.appState.isMarathi ? 'आगार निवडा' : 'Select Depot'),
                            style: widget.appState.isMarathi
                                ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.w800, color: textMain)
                                : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
                            maxLines: null,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final st = await StationPickerSheet.show(
                          context,
                          title: AppStrings.get('select_origin', widget.appState.isMarathi),
                          isMarathi: widget.appState.isMarathi,
                        );
                        if (st != null) {
                          setState(() => _origin = st);
                          _loadUpcomingDepartures(st.id);
                          _offerSetAsHome(st);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: outlineBorder),
                        ),
                        child: Text(
                          widget.appState.isMarathi ? 'बदला' : 'Change',
                          style: AppTheme.devanagari(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.msrtcRed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- MECHANICAL ROLLER PAATI (Tactile Hero Toy) ---
              RollerPaatiCard(
                services: _upcomingDepartures,
                isMarathi: widget.appState.isMarathi,
                is24Hour: widget.appState.is24Hour,
                onSelectService: _navigateToDetail,
                isLoading: !_departuresLoaded,
              ),

              const SizedBox(height: 14),

              // --- TACTILE ROUTE SEARCH CONSOLE ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: outlineBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Origin & Destination Inputs with Floating Swap Action
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            // Origin Row
                            InkWell(
                              onTap: () async {
                                final st = await StationPickerSheet.show(
                                  context,
                                  title: AppStrings.get('select_origin', widget.appState.isMarathi),
                                  isMarathi: widget.appState.isMarathi,
                                );
                                if (st != null) {
                                  setState(() => _origin = st);
                                  _loadUpcomingDepartures(st.id);
                                }
                              },
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 56, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.msrtcRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.get('from_depot', widget.appState.isMarathi),
                                            style: AppTheme.devanagari(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: textMuted,
                                            ),
                                          ),
                                          Text(
                                            _origin != null
                                                ? _origin!.displayName(widget.appState.isMarathi)
                                                : AppStrings.get('select_origin', widget.appState.isMarathi),
                                            style: widget.appState.isMarathi
                                                ? AppTheme.devanagari(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color: _origin != null ? textMain : textMuted,
                                                  )
                                                : AppTheme.latin(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: _origin != null ? textMain : textMuted,
                                                  ),
                                            maxLines: null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Crisp divider line
                            Divider(height: 1, thickness: 1, color: outlineBorder),

                            // Destination Row
                            InkWell(
                              onTap: () async {
                                final st = await StationPickerSheet.show(
                                  context,
                                  title: AppStrings.get('select_destination', widget.appState.isMarathi),
                                  isMarathi: widget.appState.isMarathi,
                                );
                                if (st != null) setState(() => _destination = st);
                              },
                              borderRadius: BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 56, 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.msrtcGold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.get('to_destination', widget.appState.isMarathi),
                                            style: AppTheme.devanagari(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: textMuted,
                                            ),
                                          ),
                                          Text(
                                            _destination != null
                                                ? _destination!.displayName(widget.appState.isMarathi)
                                                : AppStrings.get('select_destination', widget.appState.isMarathi),
                                            style: widget.appState.isMarathi
                                                ? AppTheme.devanagari(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color: _destination != null ? textMain : textMuted,
                                                  )
                                                : AppTheme.latin(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: _destination != null ? textMain : textMuted,
                                                  ),
                                            maxLines: null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Prominent Floating Swap Button
                        Positioned(
                          right: 18,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _swapStations,
                                borderRadius: BorderRadius.circular(20),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  child: Center(
                                    widthFactor: 1,
                                    heightFactor: 1,
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: surfaceContainer,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: outlineBorder, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: RotationTransition(
                                        turns: _swapRotateAnim,
                                        child: const Icon(
                                          Icons.swap_vert_rounded,
                                          size: 22,
                                          color: AppTheme.msrtcGoldDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Search Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: (_origin == null || _destination == null)
                              ? null
                              : _executeSearch,
                          style: FilledButton.styleFrom(
                            backgroundColor: (_origin == null || _destination == null)
                                ? AppTheme.msrtcRed.withValues(alpha: 0.45)
                                : AppTheme.msrtcRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.get('find_buses', widget.appState.isMarathi),
                                style: widget.appState.isMarathi
                                    ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.bold)
                                    : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // --- 1-TAP QUICK SECTOR HUBS (Dynamic for active origin) ---
              if (_frequentDestinations.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    widget.appState.isMarathi
                        ? '${_origin?.displayName(true) ?? "आगार"} येथून थेट वारंवार फेऱ्या'
                        : 'Frequent routes from ${_origin?.displayName(false) ?? "Depot"}',
                    style: AppTheme.devanagari(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _frequentDestinations.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final item = _frequentDestinations[idx];
                      final nameMr = (item['name_mr'] as String?) ?? '';
                      final nameEn = (item['name_en'] as String?) ?? '';
                      final count = (item['service_count'] as int?) ?? 0;
                      final countStr = AppStrings.toDevanagariDigits(count.toString(), widget.appState.isMarathi);

                      final destName = widget.appState.isMarathi && nameMr.isNotEmpty ? nameMr : nameEn;
                      final label = widget.appState.isMarathi
                          ? '$destName ($countStr बसेस)'
                          : '$destName ($countStr buses)';

                      return InkWell(
                        onTap: () {
                          final destStation = Station(
                            id: item['id'] as int,
                            nameEn: nameEn,
                            nameMr: nameMr,
                            isDepot: (item['is_depot'] as int?) == 1,
                          );
                          setState(() => _destination = destStation);
                          _executeSearch();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: outlineBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.msrtcGoldDark),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: widget.appState.isMarathi
                                    ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)
                                    : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // --- SCHEDULED DEPARTURES (Split-Pillar Cards) ---
              if (_upcomingDepartures.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.get('next_departures', widget.appState.isMarathi),
                        style: AppTheme.devanagari(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.fiber_manual_record_rounded, size: 8, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Text(
                            widget.appState.isMarathi ? 'थेट चालू' : 'Active',
                            style: AppTheme.devanagari(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final service in _upcomingDepartures)
                  EnamelBusCard(
                    service: service,
                    isMarathi: widget.appState.isMarathi,
                    is24Hour: widget.appState.is24Hour,
                    isSaved: _savedServiceIds.contains(service.id),
                    onToggleSave: () => _toggleSave(service),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(
                            service: service,
                            appState: widget.appState,
                            isSaved: _savedServiceIds.contains(service.id),
                            onToggleSave: () => _toggleSave(service),
                          ),
                        ),
                      );
                      if (mounted) _loadSavedIds();
                    },
                  ),
                const SizedBox(height: 16),
              ],

              // --- RECENT SEARCHES ---
              if (_recentSearches.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.get('recent_searches', widget.appState.isMarathi),
                        style: AppTheme.devanagari(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                        ),
                      ),
                      InkWell(
                        onTap: _clearRecentSearches,
                        child: Text(
                          AppStrings.get('clear_history', widget.appState.isMarathi),
                          style: AppTheme.devanagari(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.msrtcRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                for (final s in _recentSearches)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineBorder),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      leading: const Icon(Icons.history_rounded, size: 18, color: Color(0xFFB0A8A0)),
                      title: Text(
                        '${(widget.appState.isMarathi ? s['o_name_mr'] : s['o_name_en']) ?? ''} → ${(widget.appState.isMarathi ? s['d_name_mr'] : s['d_name_en']) ?? ''}',
                        style: AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold, color: textMain),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white24 : Colors.black26),
                      onTap: () async {
                        final o = await DatabaseHelper.instance.getStationById(s['o_id']);
                        final d = await DatabaseHelper.instance.getStationById(s['d_id']);
                        if (o != null && d != null && mounted) {
                          setState(() {
                            _origin = o;
                            _destination = d;
                          });
                          _loadUpcomingDepartures(o.id);
                          _executeSearch();
                        }
                      },
                    ),
                  ),
              ],

              // --- OFFLINE DATA PROVENANCE SEAL ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1716) : const Color(0xFFF2ECE4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF382926) : const Color(0xFFDFD7CD),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 20,
                      color: AppTheme.msrtcGoldDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.appState.isMarathi
                                ? 'अधिकृत वेळापत्रक डेटाबेस • १००% ऑफलाइन'
                                : 'Verified Timetable Database • 100% Offline',
                            style: widget.appState.isMarathi
                                ? AppTheme.devanagari(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  )
                                : AppTheme.latin(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                          ),
                          Text(
                            widget.appState.isMarathi
                                ? 'ऑक्टोबर २०२६ अधिकृत आगार पत्रके • इंटरनेटची गरज नाही'
                                : 'October 2026 Depot Schedules • No Internet Required',
                            style: widget.appState.isMarathi
                                ? AppTheme.devanagari(
                                    fontSize: 11,
                                    color: isDark ? textMuted : const Color(0xFF57534E),
                                  )
                                : AppTheme.latin(
                                    fontSize: 11,
                                    color: isDark ? textMuted : const Color(0xFF57534E),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
            ],
          ),
        ),
      ),
  );
  }
}
