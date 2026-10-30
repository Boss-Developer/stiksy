import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mvvm/model/sticker_template.dart';
import '../mvvm/view/premium/upgrade_view.dart';
import 'purchase_service.dart';
import 'remote_content.dart';
import 'reward_prompt.dart';

abstract class TemplateAccess {
  static SharedPreferences get _prefs => Get.find<SharedPreferences>();
  static String _key(String id) => 'stiksy_template_unlock_$id';
  static const _freeCleanKey = 'stiksy_clean_stickers_used';

  /// True while a video unlock for [template] is still running. One video
  /// pays for both the premium design and the watermark.
  static bool unlockedByVideo(StickerTemplate? template) =>
      template != null &&
      (_prefs.getInt(_key(template.id)) ?? 0) >
          DateTime.now().millisecondsSinceEpoch;

  /// Stickers the user can still take without a watermark, no video needed.
  static int get freeCleanLeft {
    final left =
        RemoteContent.settings.value.freeCleanStickers -
        (_prefs.getInt(_freeCleanKey) ?? 0);
    return left < 0 ? 0 : left;
  }

  static Future<void> useFreeClean() =>
      _prefs.setInt(_freeCleanKey, (_prefs.getInt(_freeCleanKey) ?? 0) + 1);

  static Future<bool> allow(
    BuildContext context,
    StickerTemplate template,
  ) async {
    final settings = RemoteContent.settings.value;

    if (!template.premium ||
        PurchaseService.unlocked.value ||
        !settings.rewardedVideo ||
        unlockedByVideo(template)) {
      return true;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Use this premium design'),
        content: Text(
          'Watch one short video and it’s yours: no watermark, and this design stays unlocked for ${settings.premiumUnlockHours} hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'later'),
            child: const Text('Keep editing'),
          ),
          if (settings.purchase)
            TextButton(
              onPressed: () => Navigator.pop(c, 'buy'),
              child: const Text('Remove ads for good'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'watch'),
            child: const Text('Watch video'),
          ),
        ],
      ),
    );
    if (choice == 'buy') {
      await Get.to(() => const UpgradeView());
      return PurchaseService.unlocked.value && context.mounted;
    }
    if (choice != 'watch' || !context.mounted) return false;
    if (!await watchForReward(context, unlock: 'use this design')) {
      return false;
    }
    await unlock(template);
    return context.mounted;
  }

  static Future<void> unlock(StickerTemplate template) => _prefs.setInt(
    _key(template.id),
    DateTime.now()
        .add(Duration(hours: RemoteContent.settings.value.premiumUnlockHours))
        .millisecondsSinceEpoch,
  );
}
