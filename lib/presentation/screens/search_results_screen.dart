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
import '../widgets/enamel_bus_card.dart';
import '../widgets/bus_card_skeleton.dart';
import '../widgets/connecting_route_card.dart';
import '../../models/connecting_route.dart';
import 'service_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final Station origin;
  final Station destination;
  final AppState appState;

  const SearchResultsScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.appState,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Station _currentOrigin;
  late Station _currentDestination;
  List<BusService> _allServices = [];
  List<BusService> _filteredServices = [];
  List<ConnectingRoute> _connectingRoutes = [];
  Set<int> _savedServiceIds = {};
  bool _isLoading = true;
  bool _loadFailed = false;
  Timer? _tickerTimer;

  // Filter state
  String _selectedTimeFilter = 'all';
  String _selectedTypeFilter = 'all';

  static const _categoryDefs = [
    {'key': 'ordinary', 'mr': 'साधी लालपरी', 'en': 'Ordinary'},
    {'key': 'shivshahi', 'mr': 'शिवशाही', 'en': 'Shivshahi'},
    {'key': 'shivneri', 'mr': 'शिवनेरी', 'en': 'Shivneri'},
    {'key': 'hirkani', 'mr': 'हिरकणी', 'en': 'Hirkani'},
    {'key': 'semi', 'mr': 'निम-आराम', 'en': 'Semi-Luxury'},
    {'key': 'sleeper', 'mr': 'शयनयान', 'en': 'Sleeper'},
  ];

  @override
  void initState() {
    super.initState();
    _currentOrigin = widget.origin;
    _currentDestination = widget.destination;
    _loadResults();
    _loadSavedIds();
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        // Refresh countdown text (setState) and re-run the time filter so
        // buses that already departed leave the "Upcoming" list.
        setState(() {});
        _applyFilters();
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _swapAndReload() {
    HapticFeedback.lightImpact();
    setState(() {
      final temp = _currentOrigin;
      _currentOrigin = _currentDestination;
      _currentDestination = temp;
      _isLoading = true;
      _connectingRoutes = [];
      _selectedTypeFilter = 'all';
    });
    _loadResults();
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

  Future<void> _loadResults() async {
    try {
      final results = await DatabaseHelper.instance.getServicesBetween(
        _currentOrigin.id,
        _currentDestination.id,
      );

      List<ConnectingRoute> connecting = [];
      if (results.isEmpty) {
        connecting = await DatabaseHelper.instance.findConnectingRoutes(
          _currentOrigin.id,
          _currentDestination.id,
        );
      }

      if (mounted) {
        final now = DateTime.now();
        final currentMinutes = now.hour * 60 + now.minute;
        final hasUpcoming = results.any((s) => s.depMinutes >= currentMinutes - 5);

        setState(() {
          _allServices = results;
          _connectingRoutes = connecting;
          _isLoading = false;
          _loadFailed = false;
          // Never trap user in empty upcoming screen: if no upcoming buses today, default to 'all'
          _selectedTimeFilter = hasUpcoming ? 'upcoming' : 'all';
          _selectedTypeFilter = 'all';
          _applyFilters();
        });
      }
    } catch (_) {
      // A failed read must never leave the user on an endless skeleton.
      if (mounted) {
        setState(() {
          _allServices = [];
          _filteredServices = [];
          _connectingRoutes = [];
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  String _categorizeService(BusService s) {
    final lower = s.busType.toLowerCase();
    if (lower.contains('shivneri')) return 'shivneri';
    if (lower.contains('shivshahi')) return 'shivshahi';
    if (lower.contains('hirkani')) return 'hirkani';
    if (lower.contains('semi') || lower.contains('asiad')) return 'semi';
    if (lower.contains('sleeper')) return 'sleeper';
    return 'ordinary';
  }

  Map<String, int> get _categoryCounts {
    final counts = <String, int>{'all': _allServices.length};
    for (final s in _allServices) {
      final cat = _categorizeService(s);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  String _getTypeDisplayName(String key) {
    for (final def in _categoryDefs) {
      if (def['key'] == key) {
        return widget.appState.isMarathi ? def['mr']! : def['en']!;
      }
    }
    return widget.appState.isMarathi ? 'सर्व प्रकार' : 'All Types';
  }

  int get _upcomingCount {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return _allServices.where((s) => s.depMinutes >= currentMinutes - 5).length;
  }

  int get _morningCount => _allServices.where((s) => s.depMinutes >= 240 && s.depMinutes < 720).length;
  int get _afternoonCount => _allServices.where((s) => s.depMinutes >= 720 && s.depMinutes < 1080).length;
  int get _nightCount => _allServices.where((s) => s.depMinutes >= 1080 || s.depMinutes < 240).length;

  void _applyFilters() {
    List<BusService> temp = List.from(_allServices);
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // 1. Time Filter
    if (_selectedTimeFilter == 'upcoming') {
      temp = temp.where((s) => s.depMinutes >= currentMinutes - 5).toList();
    } else if (_selectedTimeFilter == 'morning') {
      temp = temp.where((s) => s.depMinutes >= 240 && s.depMinutes < 720).toList();
    } else if (_selectedTimeFilter == 'afternoon') {
      temp = temp.where((s) => s.depMinutes >= 720 && s.depMinutes < 1080).toList();
    } else if (_selectedTimeFilter == 'night') {
      temp = temp.where((s) => s.depMinutes >= 1080 || s.depMinutes < 240).toList();
    }

    // 2. Bus Category Filter
    if (_selectedTypeFilter != 'all') {
      temp = temp.where((s) => _categorizeService(s) == _selectedTypeFilter).toList();
    }

    setState(() => _filteredServices = temp);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? const Color(0xFFFBF8F6) : AppTheme.inkPrimary;
    final textMuted = isDark ? const Color(0xFFD4C8C0) : AppTheme.inkSecondary;
    final bgParchment = isDark ? const Color(0xFF140E0D) : AppTheme.parchment;
    final outlineBorder = isDark ? const Color(0xFF382C29) : AppTheme.outline;

    final counts = _categoryCounts;
    final availableCategories = _categoryDefs.where((c) => (counts[c['key']] ?? 0) > 0).toList();
    final hasMultipleCategories = availableCategories.length > 1;

    return Scaffold(
      backgroundColor: bgParchment,
      appBar: AppBar(
        backgroundColor: bgParchment,
        foregroundColor: textMain,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _currentOrigin.displayName(widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.w800, color: textMain)
                        : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.w800, color: textMain),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.msrtcRed),
                ),
                Flexible(
                  child: Text(
                    _currentDestination.displayName(widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.w800, color: textMain)
                        : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.w800, color: textMain),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              '${AppStrings.toDevanagariDigits(_filteredServices.length.toString(), widget.appState.isMarathi)} ${AppStrings.get('buses_found', widget.appState.isMarathi)}',
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)
                  : AppTheme.latin(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _swapAndReload,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.msrtcGold.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.msrtcGoldDark.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.msrtcGoldDark),
                    const SizedBox(width: 4),
                    Text(
                      widget.appState.isMarathi ? 'परतीचा प्रवास' : 'Return',
                      style: widget.appState.isMarathi
                          ? AppTheme.devanagari(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.msrtcGoldDark)
                          : AppTheme.latin(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.msrtcGoldDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: const [
                BusCardSkeleton(),
                BusCardSkeleton(),
                BusCardSkeleton(),
                BusCardSkeleton(),
                BusCardSkeleton(),
              ],
            )
          : _loadFailed
              ? _buildLoadError(isDark: isDark, textMain: textMain, textMuted: textMuted)
              : Column(
              children: [
                // Filter shelf with 2 scrollable rails: ONLY rendered when route has buses to filter!
                if (_allServices.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: bgParchment,
                      border: Border(
                        bottom: BorderSide(color: outlineBorder.withValues(alpha: 0.6), width: 0.8),
                      ),
                    ),
                    child: Column(
                    children: [
                      // Time Filter Rail with Real-Time Counts
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Upcoming
                            _buildFilterChip(
                              key: 'upcoming',
                              label: widget.appState.isMarathi
                                  ? 'पुढील (${AppStrings.toDevanagariDigits(_upcomingCount.toString(), true)})'
                                  : 'Upcoming ($_upcomingCount)',
                              icon: Icons.bolt_rounded,
                              isDark: isDark,
                              outlineBorder: outlineBorder,
                            ),
                            const SizedBox(width: 8),

                            // All Times
                            _buildFilterChip(
                              key: 'all',
                              label: widget.appState.isMarathi
                                  ? 'सर्व वेळा (${AppStrings.toDevanagariDigits(_allServices.length.toString(), true)})'
                                  : 'All Times (${_allServices.length})',
                              icon: Icons.schedule_rounded,
                              isDark: isDark,
                              outlineBorder: outlineBorder,
                            ),
                            const SizedBox(width: 8),

                            // Morning
                            if (_morningCount > 0) ...[
                              _buildFilterChip(
                                key: 'morning',
                                label: widget.appState.isMarathi
                                    ? 'सकाळ (${AppStrings.toDevanagariDigits(_morningCount.toString(), true)})'
                                    : 'Morning ($_morningCount)',
                                icon: Icons.wb_sunny_outlined,
                                isDark: isDark,
                                outlineBorder: outlineBorder,
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Afternoon
                            if (_afternoonCount > 0) ...[
                              _buildFilterChip(
                                key: 'afternoon',
                                label: widget.appState.isMarathi
                                    ? 'दुपार (${AppStrings.toDevanagariDigits(_afternoonCount.toString(), true)})'
                                    : 'Afternoon ($_afternoonCount)',
                                icon: Icons.wb_twilight_rounded,
                                isDark: isDark,
                                outlineBorder: outlineBorder,
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Night
                            if (_nightCount > 0)
                              _buildFilterChip(
                                key: 'night',
                                label: widget.appState.isMarathi
                                    ? 'रात्र (${AppStrings.toDevanagariDigits(_nightCount.toString(), true)})'
                                    : 'Night ($_nightCount)',
                                icon: Icons.nightlight_round,
                                isDark: isDark,
                                outlineBorder: outlineBorder,
                              ),
                          ],
                        ),
                      ),

                      // Bus Category Filter Rail: ONLY rendered when route has multiple distinct categories!
                      if (hasMultipleCategories) ...[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildTypeFilterChip(
                                key: 'all',
                                label: widget.appState.isMarathi
                                    ? 'सर्व प्रकार (${AppStrings.toDevanagariDigits(_allServices.length.toString(), true)})'
                                    : 'All Types (${_allServices.length})',
                                isDark: isDark,
                                outlineBorder: outlineBorder,
                              ),
                              for (final def in availableCategories) ...[
                                const SizedBox(width: 6),
                                _buildTypeFilterChip(
                                  key: def['key']!,
                                  label: widget.appState.isMarathi
                                      ? '${def['mr']} (${AppStrings.toDevanagariDigits((counts[def['key']] ?? 0).toString(), true)})'
                                      : '${def['en']} (${counts[def['key']] ?? 0})',
                                  isDark: isDark,
                                  outlineBorder: outlineBorder,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Results List OR Context-Aware Smart Empty State
                Expanded(
                  child: _filteredServices.isEmpty
                      ? _buildEmptyState(
                          isDark: isDark,
                          textMain: textMain,
                          textMuted: textMuted,
                        )
                      : RefreshIndicator(
                          color: AppTheme.msrtcRed,
                          onRefresh: _loadResults,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                            itemCount: _filteredServices.length,
                            itemBuilder: (context, index) {
                              final service = _filteredServices[index];
                              final isSaved = _savedServiceIds.contains(service.id);

                              return EnamelBusCard(
                                service: service,
                                isMarathi: widget.appState.isMarathi,
                                is24Hour: widget.appState.is24Hour,
                                isSaved: isSaved,
                                onToggleSave: () => _toggleSave(service),
                                onTap: () async {
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
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadError({
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.msrtcRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.msrtcRed),
            ),
            const SizedBox(height: 18),
            Text(
              widget.appState.isMarathi ? 'वेळापत्रक लोड करता आले नाही' : 'Could not load the timetable',
              textAlign: TextAlign.center,
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)
                  : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 8),
            Text(
              widget.appState.isMarathi
                  ? 'डेटाबेस वाचताना अडचण आली. कृपया पुन्हा प्रयत्न करा.'
                  : 'The database hit a problem while reading. Please try again.',
              textAlign: TextAlign.center,
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 13, color: textMuted)
                  : AppTheme.latin(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                widget.appState.isMarathi ? 'पुन्हा प्रयत्न करा' : 'Try Again',
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold)
                    : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadResults();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.msrtcRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    // Case 1: Route has literally 0 direct buses in database
    if (_allServices.isEmpty) {
      if (_connectingRoutes.isNotEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 32),
          children: [
            // Prominent Connecting Route Notice
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.msrtcGold.withValues(alpha: isDark ? 0.15 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.msrtcGold.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.msrtcGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.transfer_within_a_station_rounded, color: AppTheme.msrtcGoldDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.appState.isMarathi
                              ? 'थेट बस नाही • पर्यायी कनेक्टिंग मार्ग'
                              : 'No Direct Bus • Connecting Routes',
                          style: widget.appState.isMarathi
                              ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold, color: textMain)
                              : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.appState.isMarathi
                              ? '${_currentOrigin.displayName(true)} ते ${_currentDestination.displayName(true)} थेट बस नाही, पण खालील आगारांमार्गे जाता येईल:'
                              : 'No direct bus found. You can switch buses at these intermediate depots:',
                          style: widget.appState.isMarathi
                              ? AppTheme.devanagari(fontSize: 12, color: textMuted)
                              : AppTheme.latin(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Connecting Junction Route Cards
            for (final route in _connectingRoutes)
              ConnectingRouteCard(
                route: route,
                appState: widget.appState,
              ),

            const SizedBox(height: 12),

            // Swap Return Route Button
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  widget.appState.isMarathi
                      ? 'परतीचा मार्ग शोधा (${_currentDestination.displayName(true)} → ${_currentOrigin.displayName(true)})'
                      : 'Search Return Route (${_currentDestination.displayName(false)} → ${_currentOrigin.displayName(false)})',
                  style: widget.appState.isMarathi ? AppTheme.devanagari(fontSize: 13) : AppTheme.latin(fontSize: 13),
                ),
                onPressed: _swapAndReload,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.msrtcRed,
                ),
              ),
            ),
          ],
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.msrtcRed.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore_off_rounded, size: 44, color: AppTheme.msrtcRed),
              ),
              const SizedBox(height: 18),
              Text(
                widget.appState.isMarathi ? 'या मार्गावर थेट बस उपलब्ध नाही' : 'No direct bus on this route',
                textAlign: TextAlign.center,
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)
                    : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.bold, color: textMain),
              ),
              const SizedBox(height: 8),
              Text(
                widget.appState.isMarathi
                    ? '${_currentOrigin.displayName(true)} ते ${_currentDestination.displayName(true)} दरम्यान थेट वेळापत्रक नोंद नाही. परतीचा मार्ग किंवा जवळचे मुख्य आगार तपासा.'
                    : 'No direct scheduled service between ${_currentOrigin.displayName(false)} and ${_currentDestination.displayName(false)}.',
                textAlign: TextAlign.center,
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 13, color: textMuted)
                    : AppTheme.latin(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  widget.appState.isMarathi
                      ? 'परतीचा मार्ग शोधा (${_currentDestination.displayName(true)} → ${_currentOrigin.displayName(true)})'
                      : 'Search Return Route (${_currentDestination.displayName(false)} → ${_currentOrigin.displayName(false)})',
                  style: widget.appState.isMarathi ? AppTheme.devanagari(fontSize: 13) : AppTheme.latin(fontSize: 13),
                ),
                onPressed: _swapAndReload,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.msrtcRed,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 2: Filter restricted out all buses - provide honest diagnosis and 1-tap recovery
    final String reasonTitle;
    final String reasonSubtitle;
    final String actionLabel;
    final VoidCallback onAction;

    if (_selectedTypeFilter != 'all' && (_categoryCounts[_selectedTypeFilter] ?? 0) == 0) {
      final typeName = _getTypeDisplayName(_selectedTypeFilter);
      reasonTitle = widget.appState.isMarathi
          ? 'या मार्गावर "$typeName" बस नाही'
          : 'No $typeName buses on this route';
      reasonSubtitle = widget.appState.isMarathi
          ? 'या मार्गावर एकूण ${_allServices.length} इतर बसेस उपलब्ध आहेत. सर्व बसेस पाहण्यासाठी खालील बटण दाबा.'
          : 'There are ${_allServices.length} buses available in other categories.';
      actionLabel = widget.appState.isMarathi
          ? 'सर्व ${_allServices.length} बसेस दाखवा'
          : 'Show All ${_allServices.length} Buses';
      onAction = () {
        setState(() {
          _selectedTypeFilter = 'all';
          _applyFilters();
        });
      };
    } else if (_selectedTimeFilter == 'upcoming' && _upcomingCount == 0) {
      reasonTitle = widget.appState.isMarathi
          ? 'आजच्या पुढील फेऱ्या संपल्या आहेत'
          : 'No more upcoming buses today';
      reasonSubtitle = widget.appState.isMarathi
          ? 'आजच्या सर्व ${_allServices.length} फेऱ्या आधीच सुटल्या आहेत. पूर्ण दिवसाचे वेळापत्रक पाहण्यासाठी खालील बटण दाबा.'
          : 'All ${_allServices.length} buses for today have departed. Tap below to see the full day schedule.';
      actionLabel = widget.appState.isMarathi
          ? 'संपूर्ण वेळापत्रक पहा (${_allServices.length} फेऱ्या)'
          : 'View Full Timetable (${_allServices.length} Buses)';
      onAction = () {
        setState(() {
          _selectedTimeFilter = 'all';
          _applyFilters();
        });
      };
    } else {
      reasonTitle = widget.appState.isMarathi
          ? 'निवडलेल्या वेळेत कोणतीही फेरी नाही'
          : 'No buses match this time filter';
      reasonSubtitle = widget.appState.isMarathi
          ? 'या मार्गावर एकूण ${_allServices.length} फेऱ्या उपलब्ध आहेत.'
          : 'There are ${_allServices.length} total buses scheduled on this route.';
      actionLabel = widget.appState.isMarathi
          ? 'सर्व फेऱ्या पहा (${_allServices.length} बसेस)'
          : 'Show All ${_allServices.length} Buses';
      onAction = () {
        setState(() {
          _selectedTimeFilter = 'all';
          _selectedTypeFilter = 'all';
          _applyFilters();
        });
      };
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.msrtcGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, size: 40, color: AppTheme.msrtcGoldDark),
            ),
            const SizedBox(height: 18),
            Text(
              reasonTitle,
              textAlign: TextAlign.center,
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)
                  : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 8),
            Text(
              reasonSubtitle,
              textAlign: TextAlign.center,
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 13, color: textMuted)
                  : AppTheme.latin(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                actionLabel,
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold)
                    : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.msrtcRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String key,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color outlineBorder,
  }) {
    final isSelected = _selectedTimeFilter == key;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.inkSecondary),
      ),
      label: Text(
        label,
        style: widget.appState.isMarathi
            ? AppTheme.devanagari(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF44403C)),
              )
            : AppTheme.latin(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF44403C)),
              ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.msrtcRed,
      backgroundColor: isDark ? const Color(0xFF28201E) : Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.msrtcRed : outlineBorder,
        width: 1.0,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        _selectedTimeFilter = key;
        _applyFilters();
      },
    );
  }

  Widget _buildTypeFilterChip({
    required String key,
    required String label,
    required bool isDark,
    required Color outlineBorder,
  }) {
    final isSelected = _selectedTypeFilter == key;

    return FilterChip(
      label: Text(
        label,
        style: widget.appState.isMarathi
            ? AppTheme.devanagari(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF44403C)),
              )
            : AppTheme.latin(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF44403C)),
              ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.msrtcGoldDark,
      backgroundColor: isDark ? const Color(0xFF28201E) : Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.msrtcGoldDark : outlineBorder,
        width: 1.0,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        _selectedTypeFilter = key;
        _applyFilters();
      },
    );
  }
}
