import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class AdService {
  static final ready = ValueNotifier(false);
  static bool get android => defaultTargetPlatform == TargetPlatform.android;
  static bool get supported =>
      !kIsWeb &&
      (android || defaultTargetPlatform == TargetPlatform.iOS) &&
      configured;
  static const _nativeOverride = String.fromEnvironment('ADMOB_NATIVE_ID');
  static const _rewardedOverride = String.fromEnvironment('ADMOB_REWARDED_ID');

  static bool get configured =>
      !kReleaseMode ||
      android ||
      (_nativeOverride.isNotEmpty && _rewardedOverride.isNotEmpty);

  static String get nativeId => _nativeOverride.isNotEmpty
      ? _nativeOverride
      : android
      ? (kReleaseMode
            ? 'ca-app-pub-9008446165886687/6456702836'
            : 'ca-app-pub-3940256099942544/2247696110')
      : 'ca-app-pub-3940256099942544/3986624511';
  static String get rewardedId => _rewardedOverride.isNotEmpty
      ? _rewardedOverride
      : android
      ? (kReleaseMode
            ? 'ca-app-pub-9008446165886687/2511000225'
            : 'ca-app-pub-3940256099942544/5224354917')
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
  static Completer<RewardedAd?>? _loading;

  static void cancelLoading() {
    final loading = _loading;
    if (loading != null && !loading.isCompleted) loading.complete(null);
    _cancelled = true;
  }

  static bool _cancelled = false;

  static Future<RewardResult> requestReward() async {
    if (!supported || !ready.value) return RewardResult.unavailable;
    if (_showing) return RewardResult.dismissed;
    _showing = true;
    _cancelled = false;
    final loaded = _loading = Completer<RewardedAd?>();
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
        const Duration(seconds: 8),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
      if (_cancelled) {
        ad?.dispose();
        return RewardResult.cancelled;
      }
      if (ad == null) return RewardResult.unavailable;
      final done = Completer<RewardResult>();
      bool earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!done.isCompleted) {
            done.complete(
              earned ? RewardResult.earned : RewardResult.dismissed,
            );
          }
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          if (!done.isCompleted) done.complete(RewardResult.unavailable);
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      return await done.future;
    } catch (_) {
      return RewardResult.unavailable;
    } finally {
      _showing = false;
      _loading = null;
    }
  }
}

enum RewardResult { earned, dismissed, unavailable, cancelled }
