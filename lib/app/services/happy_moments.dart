import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_radius.dart';
import '../mvvm/view/premium/upgrade_view.dart';
import 'purchase_service.dart';
import 'remote_content.dart';
import 'sticker_export_service.dart';

/// The app asks for things (a rating, a purchase) only right after the user
/// got something good, never while they are busy or frustrated.
abstract class HappyMoments {
  static const _takenKey = 'stiksy_stickers_taken';
  static const _upgradeOfferedKey = 'stiksy_upgrade_offered';
  static const _reviewAskedKey = 'stiksy_review_asked';

  /// The remove-ads offer waits until the user clearly likes the app.
  static const upgradeAfter = 5;

  static SharedPreferences get _prefs => Get.find<SharedPreferences>();
  static int get stickersTaken => _prefs.getInt(_takenKey) ?? 0;

  /// Counts a sticker the user sent, saved, shared or added to a pack.
  static Future<void> stickerTaken() =>
      _prefs.setInt(_takenKey, stickersTaken + 1);

  /// Celebrates a pack reaching WhatsApp, then asks once for a rating while
  /// the user is happiest. Someone heading off to WhatsApp is not asked: the
  /// rating card would pull them straight back into Stiksy.
  static Future<void> packAdded() async {
    HapticFeedback.mediumImpact();
    final openedWhatsApp = await Get.bottomSheet<bool>(
      const _PackAddedSheet(),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    );
    if (openedWhatsApp != true) await askForReview();
  }

  static Future<void> askForReview() async {
    if ((_prefs.getBool(_reviewAskedKey) ?? false) ||
        !StickerExportService.supported) {
      return;
    }
    try {
      await _prefs.setBool(_reviewAskedKey, true);
      // Google decides whether the card really shows; asking is never gated
      // on whether the user seems happy.
      await StickerExportService.channel.invokeMethod<bool>('requestReview');
    } catch (_) {
      // No store on this device: nothing to ask.
    }
  }

  /// Offers "Remove ads" once, after the user's 5th sticker.
  static Future<void> offerUpgradeIfDue() async {
    final s = RemoteContent.settings.value;
    if (stickersTaken < upgradeAfter ||
        !s.purchase ||
        PurchaseService.unlocked.value ||
        (_prefs.getBool(_upgradeOfferedKey) ?? false)) {
      return;
    }
    await _prefs.setBool(_upgradeOfferedKey, true);
    final upgrade = await Get.bottomSheet<bool>(
      _UpgradeOfferSheet(count: stickersTaken),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    );
    if (upgrade == true) await Get.to(() => const UpgradeView());
  }
}

class _PackAddedSheet extends StatelessWidget {
  const _PackAddedSheet();

  Widget step(String number, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0xffe8f5ee),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );

  Future<void> openWhatsApp(BuildContext context) async {
    Navigator.pop(context, true);
    try {
      await StickerExportService.channel.invokeMethod<bool>('openWhatsApp');
    } catch (_) {
      // WhatsApp missing or blocked: the steps above still explain the way.
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your pack is on WhatsApp!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          step('1', 'Open any chat in WhatsApp'),
          step('2', 'Tap the sticker icon next to the message box'),
          step('3', 'Your pack is there, ready to send'),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => openWhatsApp(context),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Open WhatsApp'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay in Stiksy'),
          ),
        ],
      ),
    ),
  );
}

class _UpgradeOfferSheet extends StatelessWidget {
  const _UpgradeOfferSheet({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '💚',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            'You’ve made $count stickers!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enjoying Stiksy? Remove ads and the watermark forever. '
            'One payment, no subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove ads forever'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe later'),
          ),
        ],
      ),
    ),
  );
}
