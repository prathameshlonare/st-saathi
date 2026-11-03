import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/station.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';

class StationPickerSheet extends StatefulWidget {
  final String title;
  final bool isMarathi;
  final ValueChanged<Station> onStationSelected;

  const StationPickerSheet({
    super.key,
    required this.title,
    required this.isMarathi,
    required this.onStationSelected,
  });

  static Future<Station?> show(
    BuildContext context, {
    required String title,
    required bool isMarathi,
  }) {
    return showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => StationPickerSheet(
        title: title,
        isMarathi: isMarathi,
        onStationSelected: (st) => Navigator.pop(context, st),
      ),
    );
  }

  @override
  State<StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<StationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  // In-memory cache for ultra-fast initial display
  static List<Station>? _cachedAllStations;
  List<Station> _stations = [];
  bool _isLoading = false;
  bool _onlyDepots = false;

  @override
  void initState() {
    super.initState();
    if (_cachedAllStations != null && _cachedAllStations!.isNotEmpty) {
      _stations = _cachedAllStations!;
    } else {
      _loadAllStations();
    }
  }

  Future<void> _loadAllStations() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.searchStations('', limit: 2000);
    _cachedAllStations = List.from(list);
    if (mounted) {
      setState(() {
        _stations = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchInputChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _filterStations(query);
    });
  }

  void _filterStations(String query) {
    final cleanQ = query.trim().toLowerCase();
    final all = _cachedAllStations ?? _stations;
    if (cleanQ.isEmpty) {
      _applyFilter(all);
      return;
    }
    final results = all.where((s) {
      final nameEn = s.nameEn.toLowerCase();
      final nameMr = s.nameMr.toLowerCase();
      return nameEn.contains(cleanQ) || nameMr.contains(cleanQ);
    }).toList()
      ..sort((a, b) {
        final aStarts = a.nameEn.toLowerCase().startsWith(cleanQ) || a.nameMr.toLowerCase().startsWith(cleanQ);
        final bStarts = b.nameEn.toLowerCase().startsWith(cleanQ) || b.nameMr.toLowerCase().startsWith(cleanQ);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return a.nameEn.compareTo(b.nameEn);
      });
    _applyFilter(results);
  }

  void _applyFilter(List<Station> results) {
    if (!mounted) return;
    setState(() {
      _stations = _onlyDepots ? results.where((s) => s.isDepot).toList() : results;
      _isLoading = false;
    });
  }

  void _toggleDepotFilter(bool selected) {
    HapticFeedback.selectionClick();
    setState(() => _onlyDepots = selected);
    _filterStations(_searchCtrl.text);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // MD3 Tonal Surface Tokens
    final sheetBg = isDark ? const Color(0xFF201A19) : const Color(0xFFFBF8F6);
    final searchBg = isDark ? const Color(0xFF2C2422) : const Color(0xFFEFE9E6);
    final dividerColor = isDark ? const Color(0xFF38302D) : const Color(0xFFE8E0DD);

    // Filter display list
    final displayList = _onlyDepots ? _stations.where((s) => s.isDepot).toList() : _stations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      // Lifts the sheet content above the on-screen keyboard so results
      // stay visible while typing.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // MD3 Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white38 : const Color(0xFFB5ABA7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: widget.isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              )
                            : AppTheme.latin(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                      ),
                      if (_cachedAllStations != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${_cachedAllStations!.length} stations'
                            '${_cachedAllStations!.where((s) => s.isDepot).isNotEmpty
                                ? ' • ${_cachedAllStations!.where((s) => s.isDepot).length} depots'
                                : ''}',
                            style: widget.isMarathi
                                ? AppTheme.devanagari(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  )
                                : AppTheme.latin(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                  tooltip: widget.isMarathi ? 'बंद करा' : 'Close',
                ),
              ],
            ),
          ),

          // MD3 Search Bar Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                autofocus: false, // Prevents keyboard clash during sheet animation
                onChanged: _onSearchInputChanged,
                textInputAction: TextInputAction.search,
                style: widget.isMarathi
                    ? AppTheme.devanagari(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      )
                    : AppTheme.latin(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                decoration: InputDecoration(
                  hintText: AppStrings.get('search_stations', widget.isMarathi),
                  hintStyle: widget.isMarathi
                      ? AppTheme.devanagari(
                          color: isDark ? const Color(0xFFA89F9C) : const Color(0xFF7D7470),
                          fontSize: 15,
                        )
                      : AppTheme.latin(
                          color: isDark ? const Color(0xFFA89F9C) : const Color(0xFF7D7470),
                          fontSize: 14,
                        ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.msrtcRed, size: 22),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filterStations('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Quick Filter Chips (All vs Depots Only)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    widget.isMarathi ? 'सर्व स्थानके' : 'All Stations',
                    style: widget.isMarathi
                        ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold)
                        : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  selected: !_onlyDepots,
                  onSelected: (val) => _toggleDepotFilter(false),
                  selectedColor: AppTheme.msrtcRed.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.msrtcRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(
                    color: !_onlyDepots ? AppTheme.msrtcRed : dividerColor,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    widget.isMarathi ? 'फक्त मुख्य आगारे' : 'Depots Only',
                    style: widget.isMarathi
                        ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold)
                        : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  selected: _onlyDepots,
                  onSelected: (val) => _toggleDepotFilter(true),
                  selectedColor: AppTheme.msrtcRed.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.msrtcRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(
                    color: _onlyDepots ? AppTheme.msrtcRed : dividerColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Virtualized 120fps Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.msrtcRed, strokeWidth: 2.5))
                : displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_rounded, size: 44, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 8),
                            Text(
                              widget.isMarathi ? 'कोणतेही स्थानक आढळले नाही' : 'No station found',
                              style: widget.isMarathi
                                  ? AppTheme.devanagari(fontSize: 15, color: const Color(0xFFB0A8A0))
                                  : AppTheme.latin(fontSize: 14, color: const Color(0xFFB0A8A0)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemExtent: 68.0, // Fixed height guarantees instant 60/120fps virtualized scrolling
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final st = displayList[index];
                          return _StationListTile(
                            station: st,
                            isMarathi: widget.isMarathi,
                            isDark: isDark,
                            onTap: () => widget.onStationSelected(st),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Highly optimized, stateless Station Tile to prevent GC churn during fast scroll
class _StationListTile extends StatelessWidget {
  final Station station;
  final bool isMarathi;
  final bool isDark;
  final VoidCallback onTap;

  const _StationListTile({
    required this.station,
    required this.isMarathi,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = station.displayName(isMarathi);
    final subtitle = station.secondaryName(isMarathi);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Icon Pill
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: station.isDepot
                    ? AppTheme.msrtcRed.withValues(alpha: 0.12)
                    : (isDark ? Colors.white10 : const Color(0xFFEBE6E3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                station.isDepot ? Icons.directions_bus_filled_rounded : Icons.location_on_outlined,
                color: station.isDepot ? AppTheme.msrtcRed : const Color(0xFFB0A8A0),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Station Names
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1C1917),
                                )
                              : AppTheme.latin(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1C1917),
                                ),
                          maxLines: null,
                        ),
                      ),
                      if (station.isDepot) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.msrtcRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppStrings.get('depot_badge', isMarathi),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.msrtcRed,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: !isMarathi
                        ? AppTheme.devanagari(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFA8A29E) : const Color(0xFFB0A8A0),
                          )
                        : AppTheme.latin(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA8A29E) : const Color(0xFFB0A8A0),
                          ),
                    maxLines: null,
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
