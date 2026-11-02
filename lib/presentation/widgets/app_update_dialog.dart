import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/app_update_service.dart';

/// Shows a popup dialog when a new app version is available.
///
/// Tapping "Update Now" opens the download page in the browser.
/// Tapping "Maybe Later" dismisses the dialog for this version.
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateCheckResult result;
  final bool isMarathi;

  const AppUpdateDialog({
    super.key,
    required this.result,
    required this.isMarathi,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppStrings.get('app_update_title', isMarathi),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('app_update_available', isMarathi),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppStrings.get('app_update_desc', isMarathi)}\n\n'
            'Version: ${result.remoteVersionName}',
            style: const TextStyle(fontSize: 14),
          ),
          if (result.changelog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.changelog,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.get('app_update_later', isMarathi)),
        ),
        ElevatedButton(
          onPressed: () async {
            final url = result.downloadUrl;
            if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          },
          child: Text(AppStrings.get('app_update_now', isMarathi)),
        ),
      ],
    );
  }
}
