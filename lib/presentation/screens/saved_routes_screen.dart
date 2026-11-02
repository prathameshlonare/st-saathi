import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bus_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/app_state.dart';
import '../widgets/enamel_bus_card.dart';
import '../widgets/bus_card_skeleton.dart';
import 'service_detail_screen.dart';

class SavedRoutesScreen extends StatefulWidget {
  final AppState appState;
  final bool isActive;

  const SavedRoutesScreen({
    super.key,
    required this.appState,
    this.isActive = false,
  });

  @override
  State<SavedRoutesScreen> createState() => SavedRoutesScreenState();
}

class SavedRoutesScreenState extends State<SavedRoutesScreen> {
  List<BusService> _savedServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      loadSavedServices();
    }
    // Otherwise load when this tab first becomes active (didUpdateWidget).
  }

  @override
  void didUpdateWidget(covariant SavedRoutesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isActive && !oldWidget.isActive) || widget.appState.isMarathi != oldWidget.appState.isMarathi) {
      loadSavedServices();
    }
  }

  Future<void> loadSavedServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_bus_ids') ?? [];
      final ids = list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();

      if (ids.isEmpty) {
        if (mounted) setState(() { _savedServices = []; _isLoading = false; });
        return;
      }

      final services = await DatabaseHelper.instance.getServicesByIds(ids);
      if (mounted) {
        setState(() {
          _savedServices = services;
          _isLoading = false;
        });
      }
    } catch (_) {
      // A failed read must never leave this tab on an endless skeleton.
      // Keep whatever is already shown; pull-to-refresh stays available.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSaved(BusService service) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_bus_ids') ?? [];
    list.remove(service.id.toString());
    await prefs.setStringList('saved_bus_ids', list);

    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _savedServices.removeWhere((s) => s.id == service.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get('remove_saved', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(fontSize: 14)
                : AppTheme.latin(fontSize: 13),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: widget.appState.isMarathi ? 'पूर्ववत करा' : 'Undo',
            textColor: AppTheme.msrtcGold,
            onPressed: () async {
              // Re-read the saved list at undo time: the earlier snapshot may
              // be stale if another bus was removed while the snackbar showed.
              final freshPrefs = await SharedPreferences.getInstance();
              final freshList = freshPrefs.getStringList('saved_bus_ids') ?? [];
              final idStr = service.id.toString();
              if (!freshList.contains(idStr)) {
                freshList.add(idStr);
              }
              await freshPrefs.setStringList('saved_bus_ids', freshList);
              loadSavedServices();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('saved', widget.appState.isMarathi)),
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: const [
                BusCardSkeleton(),
                BusCardSkeleton(),
                BusCardSkeleton(),
              ],
            )
          : _savedServices.isEmpty
              ? RefreshIndicator(
                  color: AppTheme.msrtcRed,
                  onRefresh: loadSavedServices,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.msrtcGold.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 48,
                              color: AppTheme.msrtcGoldDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.get('no_saved_routes', widget.appState.isMarathi),
                            textAlign: TextAlign.center,
                            style: widget.appState.isMarathi
                                ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.bold)
                                : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.get('no_saved_routes_sub', widget.appState.isMarathi),
                            textAlign: TextAlign.center,
                            style: widget.appState.isMarathi
                                ? AppTheme.devanagari(fontSize: 14, color: const Color(0xFFB0A8A0))
                                : AppTheme.latin(fontSize: 13, color: const Color(0xFFB0A8A0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.msrtcRed,
                  onRefresh: loadSavedServices,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _savedServices.length,
                    itemBuilder: (context, index) {
                      final service = _savedServices[index];
                      return Dismissible(
                        key: ValueKey('saved_bus_${service.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.appState.isMarathi ? 'काढून टाका' : 'Remove',
                                style: widget.appState.isMarathi
                                    ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
                                    : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        onDismissed: (_) => _removeSaved(service),
                        child: EnamelBusCard(
                          service: service,
                          isMarathi: widget.appState.isMarathi,
                          is24Hour: widget.appState.is24Hour,
                          isSaved: true,
                          onToggleSave: () => _removeSaved(service),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailScreen(
                                  service: service,
                                  appState: widget.appState,
                                  isSaved: true,
                                  onToggleSave: () => _removeSaved(service),
                                ),
                              ),
                            );
                            if (mounted) loadSavedServices();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
