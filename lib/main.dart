import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'core/app_state.dart';
import 'core/services/app_update_service.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/widgets/app_update_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Start the first frame immediately instead of waiting on the preferences
  // channel. Saved language/theme/time-format load right after.
  final appState = AppState();
  runApp(STSaathiApp(appState: appState));
  appState.loadSavedPreferences();
}

class STSaathiApp extends StatefulWidget {
  final AppState appState;

  const STSaathiApp({
    super.key,
    required this.appState,
  });

  @override
  State<STSaathiApp> createState() => _STSaathiAppState();
}

class _STSaathiAppState extends State<STSaathiApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowUpdate();
    });
  }

  Future<void> _checkAndShowUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final service = AppUpdateService();
    final versionCode = await service.getLocalVersionCode();
    final isDismissed = await service.isDismissed(versionCode);
    if (isDismissed) return;

    final result = await service.checkForAppUpdate();
    if (!mounted || !result.updateAvailable || result.downloadUrl.isEmpty) {
      return;
    }

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AppUpdateDialog(
          result: result,
          isMarathi: widget.appState.isMarathi,
        ),
      );
      // If user tapped "Maybe Later", record dismissal so we don't nag again.
      await service.dismissUpdate(versionCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds the app root when AppState changes (language/theme/time-format toggles).
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'ST Saathi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.appState.themeMode,
          home: MainNavigationScreen(
            appState: widget.appState,
          ),
        );
      },
    );
  }
}
