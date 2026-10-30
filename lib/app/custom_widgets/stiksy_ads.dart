import '../config/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_content.dart';

class StiksyAd extends StatefulWidget {
  const StiksyAd({super.key});
  @override
  State<StiksyAd> createState() => _StiksyAdState();
}

class _StiksyAdState extends State<StiksyAd> {
  NativeAd? ad;
  bool loaded = false, requested = false;
  @override
  void initState() {
    super.initState();
    AdService.ready.addListener(load);
    load();
  }

  void load() {
    if (!mounted || requested || !AdService.ready.value) return;
    requested = true;
    void success(Ad incoming) {
      if (mounted) setState(() => loaded = true);
    }

    void failure(Ad incoming, LoadAdError error) {
      incoming.dispose();
      ad = null;
    }

    ad = NativeAd(
      adUnitId: AdService.nativeId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: success,
        onAdFailedToLoad: failure,
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xfffaf7f0),
        cornerRadius: AppRadius.md,
      ),
    );
    ad!.load();
  }

  @override
  void dispose() {
    AdService.ready.removeListener(load);
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      PurchaseService.unlocked,
      RemoteContent.settings,
    ]),
    builder: (_, _) =>
        PurchaseService.unlocked.value || !RemoteContent.settings.value.ads
        ? const SizedBox.shrink()
        : _ad(),
  );

  Widget _ad() => !loaded || ad == null
      ? const SizedBox.shrink()
      : LayoutBuilder(
          builder: (_, constraints) {
            if (constraints.maxWidth < 320) return const SizedBox.shrink();
            // Framed and labelled so nobody mistakes it for a template: a
            // tap on an ad should always be on purpose.
            return Center(
              child: Container(
                width: constraints.maxWidth.clamp(320, 400),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  color: const Color(0xfffaf7f0),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: const Color(0xffe6dcc6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff82663b),
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: const Text(
                            'Ad',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sponsored · helps keep Stiksy free',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff82663b),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 120, child: AdWidget(ad: ad!)),
                  ],
                ),
              ),
            );
          },
        );
}
