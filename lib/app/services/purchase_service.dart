import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_content.dart';

abstract class PurchaseService {
  static const _buildProductId = String.fromEnvironment(
    'IAP_PRODUCT_ID',
    defaultValue: 'stiksy_remove_ads',
  );

  static String get productId {
    final published = RemoteContent.settings.value.productId.trim();
    return published.isNotEmpty ? published : _buildProductId;
  }

  static const _prefsKey = 'stiksy_ads_removed';

  static final unlocked = ValueNotifier(false);

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static final _outcome = StreamController<PurchaseOutcome>.broadcast();

  static Stream<PurchaseOutcome> get outcomes => _outcome.stream;

  static SharedPreferences get _prefs => Get.find<SharedPreferences>();

  static Future<void> initialize() async {
    unlocked.value = _prefs.getBool(_prefsKey) ?? false;
    if (!supported || _sub != null) return;
    try {
      _sub = InAppPurchase.instance.purchaseStream.listen(
        _onPurchases,
        onError: (_) => _outcome.add(PurchaseOutcome.failed),
      );
      if (!unlocked.value && defaultTargetPlatform == TargetPlatform.android) {
        // Reaching Google Play can take seconds, so never make the first
        // screen wait for it. A found purchase arrives on the stream above.
        unawaited(InAppPurchase.instance.restorePurchases().catchError((_) {}));
      }
    } catch (_) {
      // Store unavailable (emulator without Play, tests): stay on free tier.
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant();
          _outcome.add(
            p.status == PurchaseStatus.restored
                ? PurchaseOutcome.restored
                : PurchaseOutcome.purchased,
          );
        case PurchaseStatus.error:
          _outcome.add(PurchaseOutcome.failed);
        case PurchaseStatus.canceled:
          _outcome.add(PurchaseOutcome.canceled);
        case PurchaseStatus.pending:
          _outcome.add(PurchaseOutcome.pending);
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  static Future<void> _grant() async {
    await _prefs.setBool(_prefsKey, true);
    unlocked.value = true;
  }

  static Future<ProductDetails?> _query() async {
    if (!await InAppPurchase.instance.isAvailable()) return null;
    final response = await InAppPurchase.instance.queryProductDetails({
      productId,
    });
    return response.productDetails.firstOrNull;
  }

  static Future<ProductDetails?> loadProduct() async {
    if (!supported) return null;
    try {
      // A store that never answers must not leave the screen loading forever.
      return await _query().timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> buy(ProductDetails product) async {
    try {
      return await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      _outcome.add(PurchaseOutcome.failed);
    }
  }
}

enum PurchaseOutcome { purchased, restored, pending, canceled, failed }
