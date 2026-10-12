import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

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
      listener: NativeAdListener(onAdLoaded: success, onAdFailedToLoad: failure),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xfff3f7f5),
        cornerRadius: 14,
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
  Widget build(BuildContext context) => !loaded || ad == null
      ? const SizedBox.shrink()
      : LayoutBuilder(
          builder: (_, constraints) {
            if (constraints.maxWidth < 320) return const SizedBox.shrink();
            return Center(
              child: SizedBox(
                width: constraints.maxWidth.clamp(320, 400),
                height: 120,
                child: AdWidget(ad: ad!),
              ),
            );
          },
        );
}
