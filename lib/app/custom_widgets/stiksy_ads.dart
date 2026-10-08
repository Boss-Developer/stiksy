import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

class StiksyAd extends StatefulWidget {
  const StiksyAd({super.key, this.native = false});
  final bool native;
  @override
  State<StiksyAd> createState() => _StiksyAdState();
}

class _StiksyAdState extends State<StiksyAd> {
  AdWithView? ad;
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

    ad = widget.native
        ? NativeAd(
            adUnitId: AdService.nativeId,
            request: const AdRequest(),
            listener: NativeAdListener(
              onAdLoaded: success,
              onAdFailedToLoad: failure,
            ),
            nativeTemplateStyle: NativeTemplateStyle(
              templateType: TemplateType.small,
              mainBackgroundColor: const Color(0xfff3f7f5),
              cornerRadius: 14,
            ),
          )
        : BannerAd(
            adUnitId: AdService.bannerId,
            request: const AdRequest(),
            size: AdSize.banner,
            listener: BannerAdListener(
              onAdLoaded: success,
              onAdFailedToLoad: failure,
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
                width: widget.native
                    ? constraints.maxWidth.clamp(320, 400)
                    : 320,
                height: widget.native ? 120 : 50,
                child: AdWidget(ad: ad!),
              ),
            );
          },
        );
}
