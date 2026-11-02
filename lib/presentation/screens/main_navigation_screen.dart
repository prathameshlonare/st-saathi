import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database_helper.dart';
import '../../core/localization/app_strings.dart';
import '../../models/station.dart';
import '../widgets/first_launch_sheet.dart';
import 'home_search_screen.dart';
import 'saved_routes_screen.dart';
import 'settings_screen.dart';
import '../../core/app_state.dart';

class MainNavigationScreen extends StatefulWidget {
  final AppState appState;

  const MainNavigationScreen({
    super.key,
    required this.appState,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  Station? _defaultOrigin;
  final _savedKey = GlobalKey<SavedRoutesScreenState>();

  Future<void> _toggleLanguage(bool marathi) async {
    await widget.appState.saveMarathi(marathi);
    setState(() {});
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    await widget.appState.saveThemeMode(mode);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultOrigin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _loadDefaultOrigin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOriginId = prefs.getInt('default_origin_id');
    if (savedOriginId != null) {
      final station = await DatabaseHelper.instance.getStationById(savedOriginId);
      if (station != null && mounted) {
        setState(() => _defaultOrigin = station);
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isDone = prefs.getBool('first_launch_done') ?? false;

    if (!isDone && mounted) {
      await FirstLaunchSetupSheet.show(
        context,
        initialMarathi: widget.appState.isMarathi,
        initialOrigin: _defaultOrigin,
        onLanguageChanged: (marathi) {
          widget.appState.setMarathi(marathi);
        },
        onComplete: (station, isMarathi) async {
          await _updateDefaultOrigin(station);
        },
      );
      // The user closed setup with the back button without finishing it.
      // Mark it done anyway so the sheet does not reappear on every launch;
      // the full setup stays available from Settings > Re-run Initial Setup.
      final prefsAfter = await SharedPreferences.getInstance();
      if (!(prefsAfter.getBool('first_launch_done') ?? false)) {
        await prefsAfter.setBool('first_launch_done', true);
      }
    }
  }

  Future<void> _updateDefaultOrigin(Station station) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_origin_id', station.id);
    await prefs.setString('default_origin_name_en', station.nameEn);
    await prefs.setString('default_origin_name_mr', station.nameMr);

    if (mounted) {
      setState(() => _defaultOrigin = station);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeSearchScreen(
            appState: widget.appState,
            onLanguageToggle: _toggleLanguage,
            defaultOrigin: _defaultOrigin,
            onDefaultOriginChanged: _updateDefaultOrigin,
            isActive: _currentIndex == 0,
          ),
          SavedRoutesScreen(
            key: _savedKey,
            appState: widget.appState,
            isActive: _currentIndex == 1,
          ),
          SettingsScreen(
            appState: widget.appState,
            onLanguageToggle: _toggleLanguage,
            onThemeModeChanged: _changeThemeMode,
            defaultOrigin: _defaultOrigin,
            onDefaultOriginChanged: _updateDefaultOrigin,
            isActive: _currentIndex == 2,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          // SavedRoutesScreen reloads itself through didUpdateWidget when it
          // becomes the active tab, so no explicit reload call is needed here.
          setState(() => _currentIndex = idx);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search_rounded),
            label: AppStrings.get('search', widget.appState.isMarathi),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline_rounded),
            selectedIcon: const Icon(Icons.bookmark_rounded),
            label: AppStrings.get('saved', widget.appState.isMarathi),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: AppStrings.get('settings', widget.appState.isMarathi),
          ),
        ],
      ),
    );
  }
}
