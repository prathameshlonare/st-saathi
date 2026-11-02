import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:st_saathi/core/services/timetable_sync_service.dart';

/// Tests for the timetable update system: manifest parsing, the local-version
/// getters, and the network-failure path of the update check. No real network
/// access: the failure path uses an HttpClient that always throws.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteTimetableManifest.fromJson', () {
    test('parses every field from a full manifest', () {
      final manifest = RemoteTimetableManifest.fromJson({
        'version': 7,
        'version_name_en': 'November 2026 Edition',
        'version_name_mr': 'नोव्हेंबर २०२६ आवृत्ती',
        'release_date': '2026-11-01',
        'services_count': 12000,
        'stations_count': 1100,
        'download_url': 'https://example.com/timetable.db',
        'changelog_en': 'More routes',
        'changelog_mr': 'अधिक मार्ग',
      });

      expect(manifest.version, 7);
      expect(manifest.versionNameEn, 'November 2026 Edition');
      expect(manifest.versionNameMr, 'नोव्हेंबर २०२६ आवृत्ती');
      expect(manifest.releaseDate, '2026-11-01');
      expect(manifest.servicesCount, 12000);
      expect(manifest.stationsCount, 1100);
      expect(manifest.downloadUrl, 'https://example.com/timetable.db');
      expect(manifest.changelogEn, 'More routes');
      expect(manifest.changelogMr, 'अधिक मार्ग');
    });

    test('falls back to safe defaults when fields are missing', () {
      final manifest = RemoteTimetableManifest.fromJson({});

      expect(manifest.version, 1);
      expect(manifest.versionNameEn, 'Latest Edition');
      expect(manifest.versionNameMr, 'नवीन आवृत्ती');
      expect(manifest.releaseDate, '');
      expect(manifest.servicesCount, 11339);
      expect(manifest.stationsCount, 1072);
      expect(manifest.downloadUrl, '');
      expect(manifest.changelogEn, '');
      expect(manifest.changelogMr, '');
    });

    test('defaults prevent an update when download_url is empty', () {
      // checkForUpdates only offers an update when downloadUrl is non-empty,
      // so an empty manifest must not look downloadable.
      final manifest = RemoteTimetableManifest.fromJson({'version': 99});
      expect(manifest.downloadUrl, isEmpty);
    });
  });

  group('local version getters', () {
    test('default to the bundled edition when nothing is stored', () async {
      final service = TimetableSyncService.instance;

      expect(await service.getLocalVersion(), 1);
      expect(await service.getLocalVersionName(false), 'October 2026 Edition');
      expect(await service.getLocalVersionName(true), 'ऑक्टोबर २०२६ आवृत्ती');
      expect(await service.getLocalServicesCount(), 11339);
    });

    test('read stored values after an update is applied', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(TimetableSyncService.keyDbVersion, 5);
      await prefs.setString(TimetableSyncService.keyDbNameEn, 'May Edition');
      await prefs.setString(TimetableSyncService.keyDbNameMr, 'मे आवृत्ती');
      await prefs.setInt(TimetableSyncService.keyDbServicesCount, 15000);

      final service = TimetableSyncService.instance;
      expect(await service.getLocalVersion(), 5);
      expect(await service.getLocalVersionName(false), 'May Edition');
      expect(await service.getLocalVersionName(true), 'मे आवृत्ती');
      expect(await service.getLocalServicesCount(), 15000);
    });
  });

  group('checkForUpdates', () {
    test('returns networkError instead of throwing when the network fails', () async {
      HttpOverrides.global = _FailingHttpOverrides();
      final result = await TimetableSyncService.instance.checkForUpdates();
      expect(result.status, SyncStatus.networkError);
      expect(result.errorMessage, isNotNull);
      expect(result.manifest, isNull);
    });
  });
}

/// HttpClient whose requests always fail, standing in for no connectivity.
class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailingHttpClient();
}

class _FailingHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      throw const SocketException('no network in tests');
    }
    // Everything else (setters, close) is a no-op.
    return null;
  }
}
