import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/timetable_sync_service.dart';
import '../../models/station.dart';
import '../../core/app_state.dart';
import '../widgets/first_launch_sheet.dart';
import '../widgets/station_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;
  final ValueChanged<bool> onLanguageToggle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Station? defaultOrigin;
  final ValueChanged<Station>? onDefaultOriginChanged;
  final bool isActive;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.onLanguageToggle,
    required this.onThemeModeChanged,
    this.defaultOrigin,
    this.onDefaultOriginChanged,
    this.isActive = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingUpdates = false;
  String _currentVersionName = '';
  int _currentServicesCount = 11339;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _loadCurrentDbMeta();
    }
    // Otherwise load when this tab first becomes active (didUpdateWidget).
  }

  Future<void> _loadCurrentDbMeta() async {
    final name = await TimetableSyncService.instance.getLocalVersionName(widget.appState.isMarathi);
    final count = await TimetableSyncService.instance.getLocalServicesCount();
    if (mounted) {
      setState(() {
        _currentVersionName = name;
        _currentServicesCount = count;
      });
    }
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadCurrentDbMeta();
    }
    if (widget.appState.isMarathi != oldWidget.appState.isMarathi) {
      _loadCurrentDbMeta();
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    await prefs.remove('saved_bus_ids');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.isMarathi ? 'शोध इतिहास व जतन केलेल्या बसेस साफ केल्या' : 'Cleared history and saved routes',
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(fontSize: 14)
                : AppTheme.latin(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeDefaultDepot(BuildContext context) async {
    HapticFeedback.lightImpact();
    final station = await StationPickerSheet.show(
      context,
      title: AppStrings.get('select_home_depot', widget.appState.isMarathi),
      isMarathi: widget.appState.isMarathi,
    );

    if (station != null) {
      widget.onDefaultOriginChanged?.call(station);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${station.displayName(widget.appState.isMarathi)} ${AppStrings.get('depot_saved_toast', widget.appState.isMarathi)}',
              style: widget.appState.isMarathi
                  ? AppTheme.devanagari(fontSize: 14)
                  : AppTheme.latin(fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rerunSetup(BuildContext context) async {
    HapticFeedback.lightImpact();
    FirstLaunchSetupSheet.show(
      context,
      initialMarathi: widget.appState.isMarathi,
      initialOrigin: widget.defaultOrigin,
      onLanguageChanged: widget.onLanguageToggle,
      isDismissible: true,
      onComplete: (station, marathi) async {
        widget.onDefaultOriginChanged?.call(station);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.get('setup_complete', marathi),
                style: marathi
                    ? AppTheme.devanagari(fontSize: 14)
                    : AppTheme.latin(fontSize: 13),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _checkTimetableUpdates(BuildContext context) async {
    HapticFeedback.lightImpact();
    setState(() => _isCheckingUpdates = true);

    final result = await TimetableSyncService.instance.checkForUpdates();
    if (!context.mounted) return;
    setState(() => _isCheckingUpdates = false);

    if (result.status == SyncStatus.upToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get('latest_version_installed', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(fontSize: 14)
                : AppTheme.latin(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.status == SyncStatus.networkError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get('update_failed', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(fontSize: 14)
                : AppTheme.latin(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.status == SyncStatus.updateAvailable && result.manifest != null) {
      _showUpdateSheet(context, result.manifest!);
    }
  }

  void _showUpdateSheet(BuildContext context, RemoteTimetableManifest manifest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF221A19) : Colors.white;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.msrtcGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_download_rounded, color: AppTheme.msrtcGoldDark, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('new_version_found', widget.appState.isMarathi),
                              style: widget.appState.isMarathi
                                  ? AppTheme.devanagari(fontSize: 18, fontWeight: FontWeight.bold)
                                  : AppTheme.latin(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.appState.isMarathi ? manifest.versionNameMr : manifest.versionNameEn,
                              style: widget.appState.isMarathi
                                  ? AppTheme.devanagari(fontSize: 13, color: const Color(0xFFB0A8A0))
                                  : AppTheme.latin(fontSize: 13, color: const Color(0xFFB0A8A0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (manifest.changelogMr.isNotEmpty || manifest.changelogEn.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2220) : const Color(0xFFF5EBE6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.appState.isMarathi ? manifest.changelogMr : manifest.changelogEn,
                        style: widget.appState.isMarathi
                            ? AppTheme.devanagari(fontSize: 13)
                            : AppTheme.latin(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        color: AppTheme.msrtcRed,
                        backgroundColor: AppTheme.msrtcRed.withValues(alpha: 0.15),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '${(downloadProgress * 100).toInt()}% • ${AppStrings.get('downloading_timetable', widget.appState.isMarathi)}',
                        style: widget.appState.isMarathi
                            ? AppTheme.devanagari(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.msrtcRed)
                            : AppTheme.latin(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.msrtcRed),
                      ),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: () async {
                        setModalState(() => isDownloading = true);
                        final success = await TimetableSyncService.instance.downloadAndApplyUpdate(
                          manifest,
                          onProgress: (p) {
                            setModalState(() => downloadProgress = p);
                          },
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _loadCurrentDbMeta();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? AppStrings.get('update_complete', widget.appState.isMarathi)
                                    : AppStrings.get('update_failed', widget.appState.isMarathi),
                                style: widget.appState.isMarathi
                                    ? AppTheme.devanagari(fontSize: 14)
                                    : AppTheme.latin(fontSize: 13),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.msrtcRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        AppStrings.get('update_now', widget.appState.isMarathi),
                        style: widget.appState.isMarathi
                            ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.bold)
                            : AppTheme.latin(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('settings', widget.appState.isMarathi)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Language Selection ---
          Text(
            AppStrings.get('language', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  )
                : AppTheme.latin(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'मराठी (Marathi)',
                    style: AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'मराठी देवनागरी अंक व स्थानक नावे',
                    style: AppTheme.devanagari(fontSize: 13, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: widget.appState.isMarathi
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.msrtcRed)
                      : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFA8A29E)),
                  onTap: () => widget.onLanguageToggle(true),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'English',
                    style: AppTheme.latin(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'English labels and 24-hr time',
                    style: AppTheme.latin(fontSize: 13, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: !widget.appState.isMarathi
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.msrtcRed)
                      : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFA8A29E)),
                  onTap: () => widget.onLanguageToggle(false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Time Format ---
          Text(
            AppStrings.get('time_format', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  )
                : AppTheme.latin(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: AppTheme.msrtcRed, size: 22),
                  title: Text(
                    AppStrings.get('time_format_24', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w700)
                        : AppTheme.latin(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    widget.appState.isMarathi
                        ? 'सकाळ १२ ते रात्री १२ पर्यंत'
                        : 'Midnight to midnight',
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 12, color: const Color(0xFFB0A8A0))
                        : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: widget.appState.is24Hour
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.msrtcRed)
                      : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFA8A29E)),
                  onTap: () => widget.appState.saveTimeFormat24Hour(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.access_alarm_rounded, color: AppTheme.msrtcGoldDark, size: 22),
                  title: Text(
                    AppStrings.get('time_format_12', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w700)
                        : AppTheme.latin(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    widget.appState.isMarathi
                        ? 'सकाळ / संध्याकाळ AM PM सह'
                        : 'AM / PM with morning and evening',
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 12, color: const Color(0xFFB0A8A0))
                        : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: !widget.appState.is24Hour
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.msrtcRed)
                      : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFA8A29E)),
                  onTap: () => widget.appState.saveTimeFormat24Hour(false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Default Home Departure Depot ---
          Text(
            AppStrings.get('home_depot', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  )
                : AppTheme.latin(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.msrtcRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_rounded, color: AppTheme.msrtcRed, size: 22),
                  ),
                  title: Text(
                    widget.defaultOrigin != null
                        ? widget.defaultOrigin!.displayName(widget.appState.isMarathi)
                        : (widget.appState.isMarathi ? 'अमरावती आगार (डीफॉल्ट)' : 'Amravati Depot (Default)'),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w700)
                        : AppTheme.latin(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppStrings.get('home_depot_desc', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 12, color: const Color(0xFFB0A8A0))
                        : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: TextButton(
                    onPressed: () => _changeDefaultDepot(context),
                    child: Text(
                      widget.appState.isMarathi ? 'बदला' : 'Change',
                      style: widget.appState.isMarathi
                          ? AppTheme.devanagari(fontWeight: FontWeight.bold, color: AppTheme.msrtcRed)
                          : AppTheme.latin(fontWeight: FontWeight.bold, color: AppTheme.msrtcRed),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: AppTheme.msrtcGoldDark, size: 22),
                  title: Text(
                    AppStrings.get('rerun_setup', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.w600)
                        : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.appState.isMarathi ? 'भाषा व मुख्य आगार पुन्हा सेट करा' : 'Reconfigure language & home depot',
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 12, color: const Color(0xFFB0A8A0))
                        : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA8A29E)),
                  onTap: () => _rerunSetup(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Appearance / Theme ---
          Text(
            widget.appState.isMarathi ? 'स्वरूप (Theme)' : 'Appearance',
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  )
                : AppTheme.latin(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(
                widget.appState.isMarathi ? 'गडद रंग (Dark Mode)' : 'Dark Theme',
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w600)
                    : AppTheme.latin(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.appState.isMarathi ? 'डोळ्यांना आराम व बॅटरी बचत' : 'Low light and battery saving',
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 13, color: const Color(0xFFB0A8A0))
                    : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
              ),
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppTheme.msrtcRed,
              ),
              value: widget.appState.themeMode == ThemeMode.dark,
              activeTrackColor: AppTheme.msrtcRed,
              onChanged: (val) {
                widget.onThemeModeChanged(val ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),

          const SizedBox(height: 24),

          // --- Dataset Information & OTA Live Sync ---
          Text(
            AppStrings.get('data_info', widget.appState.isMarathi),
            style: widget.appState.isMarathi
                ? AppTheme.devanagari(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  )
                : AppTheme.latin(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.msrtcRed,
                  ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppTheme.msrtcGoldDark, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentVersionName.isNotEmpty
                              ? '${AppStrings.get('dataset_version', widget.appState.isMarathi)}: $_currentVersionName'
                              : '${AppStrings.get('dataset_version', widget.appState.isMarathi)}: October 2026',
                          style: widget.appState.isMarathi
                              ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.bold)
                              : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.get('depot_coverage', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF44403C))
                        : AppTheme.latin(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF44403C)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.appState.isMarathi
                        ? '• एकूण वेळापत्रक: ${AppStrings.toDevanagariDigits(_currentServicesCount.toString(), true)} प्रस्थान नोंदी\n• स्थानके व आगारे: १,०७२ स्थानके\n• १००% ऑफलाईन कार्यरत'
                        : '• Total Services: $_currentServicesCount Scheduled Departures\n• Stations & Depots: 1,072 Stations\n• 100% Offline Operational',
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(fontSize: 13, color: const Color(0xFFB0A8A0))
                        : AppTheme.latin(fontSize: 12, color: const Color(0xFFB0A8A0)),
                  ),
                  const SizedBox(height: 14),

                  // OTA Sync Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isCheckingUpdates ? null : () => _checkTimetableUpdates(context),
                      icon: _isCheckingUpdates
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.msrtcRed),
                            )
                          : const Icon(Icons.sync_rounded, size: 18, color: AppTheme.msrtcRed),
                      label: Text(
                        _isCheckingUpdates
                            ? AppStrings.get('checking_updates', widget.appState.isMarathi)
                            : AppStrings.get('check_updates', widget.appState.isMarathi),
                        style: widget.appState.isMarathi
                            ? AppTheme.devanagari(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isCheckingUpdates ? const Color(0xFFB0A8A0) : AppTheme.msrtcRed,
                              )
                            : AppTheme.latin(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isCheckingUpdates ? const Color(0xFFB0A8A0) : AppTheme.msrtcRed,
                              ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.msrtcRed),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const Divider(height: 24),
                  Text(
                    AppStrings.get('disclaimer', widget.appState.isMarathi),
                    style: widget.appState.isMarathi
                        ? AppTheme.devanagari(
                            fontSize: 12,
                            color: const Color(0xFFB0A8A0),
                          )
                        : AppTheme.latin(
                            fontSize: 12,
                            color: const Color(0xFFB0A8A0),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Data Management ---
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              title: Text(
                widget.appState.isMarathi ? 'शोध इतिहास व बुकमार्क साफ करा' : 'Clear History & Bookmarks',
                style: widget.appState.isMarathi
                    ? AppTheme.devanagari(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.redAccent)
                    : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      widget.appState.isMarathi ? 'सर्व माहिती साफ करायची?' : 'Clear all saved data?',
                      style: widget.appState.isMarathi
                          ? AppTheme.devanagari(fontSize: 16, fontWeight: FontWeight.w700)
                          : AppTheme.latin(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      widget.appState.isMarathi
                          ? 'तुमचे सर्व जतन केलेल्या बसेस व शोध इतिहास कायमचे काढले जातील. ही कृती पूर्ववत करता येणार नाही.'
                          : 'All your saved buses and search history will be deleted permanently. This cannot be undone.',
                      style: widget.appState.isMarathi
                          ? AppTheme.devanagari(fontSize: 14)
                          : AppTheme.latin(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          widget.appState.isMarathi ? 'रद्द करा' : 'Cancel',
                          style: widget.appState.isMarathi
                              ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.w600)
                              : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          widget.appState.isMarathi ? 'हटवा' : 'Delete',
                          style: widget.appState.isMarathi
                              ? AppTheme.devanagari(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.redAccent)
                              : AppTheme.latin(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await _clearAllData(context);
                }
              },
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              widget.appState.isMarathi
                  ? 'ST Saathi v1.1 • महाराष्ट्रासाठी बनवले'
                  : 'ST Saathi v1.1 • Made for Maharashtra',
              style: AppTheme.latin(
                fontSize: 13,
                letterSpacing: 0.5,
                color: const Color(0xFFA8A29E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
