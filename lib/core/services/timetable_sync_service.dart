import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

enum SyncStatus {
  upToDate,
  updateAvailable,
  networkError,
}

class RemoteTimetableManifest {
  final int version;
  final String versionNameEn;
  final String versionNameMr;
  final String releaseDate;
  final int servicesCount;
  final int stationsCount;
  final String downloadUrl;
  final String changelogEn;
  final String changelogMr;

  const RemoteTimetableManifest({
    required this.version,
    required this.versionNameEn,
    required this.versionNameMr,
    required this.releaseDate,
    required this.servicesCount,
    required this.stationsCount,
    required this.downloadUrl,
    required this.changelogEn,
    required this.changelogMr,
  });

  factory RemoteTimetableManifest.fromJson(Map<String, dynamic> json) {
    return RemoteTimetableManifest(
      version: json['version'] as int? ?? 1,
      versionNameEn: json['version_name_en'] as String? ?? 'Latest Edition',
      versionNameMr: json['version_name_mr'] as String? ?? 'नवीन आवृत्ती',
      releaseDate: json['release_date'] as String? ?? '',
      servicesCount: json['services_count'] as int? ?? 11339,
      stationsCount: json['stations_count'] as int? ?? 1072,
      downloadUrl: json['download_url'] as String? ?? '',
      changelogEn: json['changelog_en'] as String? ?? '',
      changelogMr: json['changelog_mr'] as String? ?? '',
    );
  }
}

class SyncCheckResult {
  final SyncStatus status;
  final RemoteTimetableManifest? manifest;
  final String? errorMessage;

  const SyncCheckResult({
    required this.status,
    this.manifest,
    this.errorMessage,
  });
}

class TimetableSyncService {
  static final TimetableSyncService instance = TimetableSyncService._init();
  TimetableSyncService._init();

  // Primary GitHub Raw manifest endpoint for OTA updates
  static const String manifestUrl =
      'https://raw.githubusercontent.com/st-saathi/timetable-data/main/manifest.json';

  static const String keyDbVersion = 'ota_db_version';
  static const String keyDbNameEn = 'ota_db_name_en';
  static const String keyDbNameMr = 'ota_db_name_mr';
  static const String keyDbServicesCount = 'ota_db_services_count';
  static const String keyLastCheckTime = 'ota_last_check_timestamp';

  Future<int> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyDbVersion) ?? 1;
  }

  Future<String> getLocalVersionName(bool isMarathi) async {
    final prefs = await SharedPreferences.getInstance();
    if (isMarathi) {
      return prefs.getString(keyDbNameMr) ?? 'ऑक्टोबर २०२६ आवृत्ती';
    }
    return prefs.getString(keyDbNameEn) ?? 'October 2026 Edition';
  }

  Future<int> getLocalServicesCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyDbServicesCount) ?? 11339;
  }

  /// Checks remote manifest for newer timetable version
  Future<SyncCheckResult> checkForUpdates() async {
    HttpClient? client;
    try {
      final currentVersion = await getLocalVersion();

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      final uri = Uri.parse(manifestUrl);
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return SyncCheckResult(
          status: SyncStatus.networkError,
          errorMessage: 'Server responded with code ${response.statusCode}',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json = jsonDecode(responseBody) as Map<String, dynamic>;
      final manifest = RemoteTimetableManifest.fromJson(json);

      // Record check timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);

      if (manifest.version > currentVersion && manifest.downloadUrl.isNotEmpty) {
        return SyncCheckResult(
          status: SyncStatus.updateAvailable,
          manifest: manifest,
        );
      }

      return SyncCheckResult(
        status: SyncStatus.upToDate,
        manifest: manifest,
      );
    } catch (e) {
      return SyncCheckResult(
        status: SyncStatus.networkError,
        errorMessage: e.toString(),
      );
    } finally {
      client?.close(force: true);
    }
  }

  /// Streams the remote SQLite database to a temporary file, verifies it,
  /// and atomically swaps it into the active DatabaseHelper.
  Future<bool> downloadAndApplyUpdate(
    RemoteTimetableManifest manifest, {
    void Function(double progress)? onProgress,
  }) async {
    HttpClient? client;
    File? tempFile;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      tempFile = File('${appDir.path}/temp_timetable_sync.db');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(manifest.downloadUrl);
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return false;
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();
      try {
        // If no data arrives for 30s the connection is stalled; abort instead
        // of showing a progress percentage that never completes.
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.flush();
      } finally {
        // Always close so Windows can delete the temp file (locked otherwise).
        await sink.close();
      }

      // Verify the downloaded file is a valid non-empty file
      final fileSize = await tempFile.length();
      if (fileSize < 500000) {
        // MSRTC SQLite database is at least 3MB; anything under 500KB is incomplete
        await tempFile.delete();
        return false;
      }

      // Atomically swap in the new database
      final success = await DatabaseHelper.instance.replaceDatabase(tempFile);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(keyDbVersion, manifest.version);
        await prefs.setString(keyDbNameEn, manifest.versionNameEn);
        await prefs.setString(keyDbNameMr, manifest.versionNameMr);
        await prefs.setInt(keyDbServicesCount, manifest.servicesCount);
      }

      return success;
    } catch (e) {
      return false;
    } finally {
      client?.close(force: true);
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }
}
