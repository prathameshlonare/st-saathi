import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:st_saathi/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('checks a real GitHub Pages URL, not a placeholder', () {
      final uri = Uri.parse(AppUpdateService.metadataUrl);

      expect(uri.scheme, 'https');
      expect(uri.host, 'prathameshlonare.github.io');
      expect(uri.path, '/st-saathi/release-metadata.json');
      expect(AppUpdateService.metadataUrl, isNot(contains('<')));
    });

    test('reports the build number the platform reports', () async {
      PackageInfo.setMockInitialValues(
        appName: 'ST Saathi',
        packageName: 'com.stsaathi.st_saathi',
        version: '1.0.1',
        buildNumber: '7',
        buildSignature: '',
      );

      final service = AppUpdateService();

      expect(await service.getLocalVersionCode(), 7);
    });
  });
}
