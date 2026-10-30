import '../../../config/app_radius.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../custom_widgets/stiksy_crown.dart';
import '../../../services/purchase_service.dart';
import '../../../services/remote_content.dart';

class UpgradeView extends StatefulWidget {
  const UpgradeView({super.key});
  @override
  State<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends State<UpgradeView> {
  late Future<ProductDetails?> product = PurchaseService.loadProduct();
  StreamSubscription<PurchaseOutcome>? _outcomes;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _outcomes = PurchaseService.outcomes.listen((outcome) {
      if (!mounted) return;
      setState(() => busy = false);
      switch (outcome) {
        case PurchaseOutcome.purchased:
          'Thank you! Ads and watermarks are gone.'.showSuccess();
        case PurchaseOutcome.restored:
          'Purchase restored. Welcome back!'.showSuccess();
        case PurchaseOutcome.pending:
          'Payment is pending. We’ll unlock everything as soon as it clears.'
              .showInfo();
        case PurchaseOutcome.canceled:
          break;
        case PurchaseOutcome.failed:
          'Something went wrong. You were not charged. Please try again.'
              .showError();
      }
    });
  }

  @override
  void dispose() {
    _outcomes?.cancel();
    super.dispose();
  }

  Future<void> buy(ProductDetails details) async {
    setState(() => busy = true);
    // The result arrives on PurchaseService.outcomes; only a refusal to start
    // the flow has to be handled here.
    if (!await PurchaseService.buy(details) && mounted) {
      setState(() => busy = false);
      'Could not open the store. Please try again.'.showError();
    }
  }

  Future<void> restore() async {
    setState(() => busy = true);
    await PurchaseService.restore();
    // Nothing to restore produces no store event, so don't stay busy forever.
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    setState(() => busy = false);
    if (!PurchaseService.unlocked.value) {
      'No earlier purchase found on this account.'.showInfo();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgColor,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textDarkColor,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ValueListenableBuilder<bool>(
            valueListenable: PurchaseService.unlocked,
            builder: (context, owned, _) {
              final settings = RemoteContent.settings.value;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(child: StiksyCrown(size: 40)),
                  const SizedBox(height: 12),
                  Text(
                    owned ? 'You’re all set' : settings.upgradeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      color: AppColors.textDarkColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    owned
                        ? 'Thank you for supporting Stiksy. Enjoy a clean, ad-free studio.'
                        : settings.upgradeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textLightBlack,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Column(
                      children: [
                        for (final label in settings.upgradeBenefits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Icon(
                                  owned
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color: AppColors.primary,
                                  size: 21,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(label)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (owned)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          )
                        else
                          FutureBuilder<ProductDetails?>(
                            future: product,
                            builder: (context, snapshot) {
                              final details = snapshot.data;
                              final loading =
                                  snapshot.connectionState !=
                                  ConnectionState.done;
                              // A grey "Store unavailable" button reads as
                              // "broken"; say what happened and what to do.
                              final unavailable = !loading && details == null;
                              return Column(
                                children: [
                                  if (unavailable) ...[
                                    const Text(
                                      'Google Play couldn’t show the price right now. '
                                      'Check your internet and that Google Play is signed in, '
                                      'then try again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textLightBlack,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(52),
                                      ),
                                      onPressed: busy || loading
                                          ? null
                                          : unavailable
                                          ? () => setState(
                                              () => product =
                                                  PurchaseService.loadProduct(),
                                            )
                                          : () => buy(details!),
                                      child: Text(
                                        loading
                                            ? 'Loading price…'
                                            : unavailable
                                            ? 'Try again'
                                            : busy
                                            ? 'Processing…'
                                            : 'Buy once for ${details!.price}',
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: busy ? null : restore,
                                    child: const Text('Restore purchase'),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
