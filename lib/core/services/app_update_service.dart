import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of an app update check.
class AppUpdateCheckResult {
  final bool updateAvailable;
  final int remoteVersionCode;
  final String remoteVersionName;
  final String downloadUrl;
  final String changelog;
  final String? errorMessage;

  const AppUpdateCheckResult({
    required this.updateAvailable,
    required this.remoteVersionCode,
    required this.remoteVersionName,
    required this.downloadUrl,
    required this.changelog,
    this.errorMessage,
  });
}

/// Checks GitHub Pages for a new app version.
///
/// The app reads `release-metadata.json` hosted on GitHub Pages and compares
/// the remote `versionCode` with the local one. If a newer version exists, it
/// returns the download URL so the user can update.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Where the update manifest lives on GitHub Pages.
  static const String _metadataUrl =
      'https://prathameshlonare.github.io/st-saathi/release-metadata.json';

  @visibleForTesting
  static String get metadataUrl => _metadataUrl;

  static const String _keyLastAppUpdateCheck = 'app_last_update_check';
  static const Duration _checkInterval = Duration(hours: 24);

  /// Checks for a new app version. Returns [AppUpdateCheckResult].
  ///
  /// Only checks once per day to avoid hammering the server.
  Future<AppUpdateCheckResult> checkForAppUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_keyLastAppUpdateCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Skip if checked within the last 24 hours
      if (now - lastCheck < _checkInterval.inMilliseconds) {
        return const AppUpdateCheckResult(
          updateAvailable: false,
          remoteVersionCode: 0,
          remoteVersionName: '',
          downloadUrl: '',
          changelog: '',
        );
      }

      await prefs.setInt(_keyLastAppUpdateCheck, now);

      final uri = Uri.parse(_metadataUrl);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return AppUpdateCheckResult(
          updateAvailable: false,
          remoteVersionCode: 0,
          remoteVersionName: '',
          downloadUrl: '',
          changelog: '',
          errorMessage: 'Server responded with code ${response.statusCode}',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json =
          jsonDecode(responseBody) as Map<String, dynamic>;

      final remoteVersionCode = json['versionCode'] as int? ?? 0;
      final remoteVersionName = json['versionName'] as String? ?? '';
      final downloadUrl = json['downloadUrl'] as String? ?? '';
      final changelog = json['changelog'] as String? ?? '';

      final localVersionCode = await getLocalVersionCode();

      return AppUpdateCheckResult(
        updateAvailable: remoteVersionCode > localVersionCode,
        remoteVersionCode: remoteVersionCode,
        remoteVersionName: remoteVersionName,
        downloadUrl: downloadUrl,
        changelog: changelog,
      );
    } catch (e) {
      return AppUpdateCheckResult(
        updateAvailable: false,
        remoteVersionCode: 0,
        remoteVersionName: '',
        downloadUrl: '',
        changelog: '',
        errorMessage: e.toString(),
      );
    }
  }

  /// Returns the real version code of the installed build.
  ///
  /// On Android this is the Gradle `versionCode`, which comes from the build
  /// number in `pubspec.yaml` (`version: 1.0.0+1` → 1). GitHub Actions builds
  /// from the same file, so the app and the update manifest stay in step.
  /// Falls back to 1 if the platform refuses to answer, so a broken update
  /// check can never block startup.
  Future<int> getLocalVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Records that the user dismissed the update, so we don't nag again
  /// for this version.
  Future<void> dismissUpdate(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_update_dismissed_$versionCode', 1);
  }

  /// Returns true if the user already dismissed this version's update.
  Future<bool> isDismissed(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('app_update_dismissed_$versionCode') == 1;
  }
}
