import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../custom_widgets/snackbars/app_snackbar.dart';
import 'remote_content.dart';

abstract class AppGate {
  static bool _maintenanceShown = false;
  static bool _updateShown = false;

  static Future<void> check() async {
    final s = RemoteContent.settings.value;
    final notice = s.maintenanceMessage.trim();
    if (notice.isNotEmpty && !_maintenanceShown) {
      _maintenanceShown = true;
      Get.dialog(
        AlertDialog(
          title: const Text('Stiksy is being updated'),
          content: Text(notice),
          actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
        ),
      );
    }
    if (_updateShown) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (compareVersions(info.version, s.minVersion) >= 0) return;
      _updateShown = true;
      final store = storeUri(s.storeUrl, info.packageName);
      Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Please update Stiksy'),
            content: Text(s.updateMessage),
            actions: [
              // The dialog cannot be closed, so it must always offer the way
              // out; without a store link the user is never blocked.
              if (store == null)
                TextButton(onPressed: Get.back, child: const Text('Later'))
              else
                FilledButton(
                  onPressed: () => _open(store),
                  child: const Text('Update now'),
                ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    } catch (_) {
      // Version unknown (tests, unsupported platform): never block the user.
    }
  }

  /// The admin's store link wins; Android falls back to the Play listing.
  @visibleForTesting
  static Uri? storeUri(String configured, String packageName) {
    if (configured.trim().isNotEmpty) return Uri.tryParse(configured.trim());
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Uri.https('play.google.com', '/store/apps/details', {
        'id': packageName,
      });
    }
    return null;
  }

  static Future<void> _open(Uri store) async {
    final ok = await launchUrl(
      store,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok) {
      'Couldn’t open the store. Please update Stiksy from there.'.showError();
    }
  }
}
