import '../custom_widgets/snackbars/app_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mvvm/model/sticker_template.dart';
import 'ad_service.dart';

abstract class TemplateAccess {
  static Future<bool> allow(
    BuildContext context,
    StickerTemplate template,
  ) async {
    if (!template.premium) return true;
    final prefs = Get.find<SharedPreferences>();
    final key = 'stiksy_template_unlock_${template.id}';
    if ((prefs.getInt(key) ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    final watch = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unlock premium template'),
        content: const Text(
          'Complete a video to unlock this template for 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Watch video'),
          ),
        ],
      ),
    );
    if (watch != true || !context.mounted) return false;
    'Loading video…'.showInfo();
    final reward = await AdService.watchReward();
    if (!context.mounted) return false;
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    if (!reward) {
      'No reward earned. Connect to the internet and complete the video to unlock.'
          .showWarning();
      return false;
    }
    await prefs.setInt(
      key,
      DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
    );
    return context.mounted;
  }
}
