import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Official Google sample IDs only. No production ad traffic in this build.
abstract class AdService {
  static final ready = ValueNotifier(false);
  static bool get android => defaultTargetPlatform == TargetPlatform.android;
  static bool get supported =>
      !kIsWeb && (android || defaultTargetPlatform == TargetPlatform.iOS);
  static String get bannerId => android
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';
  static String get nativeId => android
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-3940256099942544/3986624511';
  static String get rewardedId => android
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';
  static Future<void> initialize() async {
    if (!supported) return;
    try {
      await MobileAds.instance.initialize();
      ready.value = true;
    } catch (_) {
      ready.value = false;
    }
  }

  static bool _showing = false;
  static Future<bool> watchReward() async {
    if (!ready.value || _showing) return false;
    _showing = true;
    final loaded = Completer<RewardedAd?>();
    try {
      await RewardedAd.load(
        adUnitId: rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!loaded.isCompleted) {
              loaded.complete(ad);
            } else {
              ad.dispose();
            }
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      final ad = await loaded.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
      if (ad == null) return false;
      final done = Completer<bool>();
      bool earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!done.isCompleted) done.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          if (!done.isCompleted) done.complete(false);
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      return await done.future;
    } catch (_) {
      return false;
    } finally {
      _showing = false;
    }
  }
}
