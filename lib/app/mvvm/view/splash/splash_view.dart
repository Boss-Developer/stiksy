import 'package:flutter/material.dart';

import '../../../services/remote_content.dart';
import 'package:get/get.dart';
import '../../../config/app_radius.dart';
import '../../../config/app_colors.dart';

import '../../../custom_widgets/sticker_components.dart';
import '../../model/sticker_template.dart';
import '../../view_model/splash/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  Widget _setup(BuildContext context) {
    switch (controller.phase.value) {
      case SplashPhase.logo:
        return const SizedBox.shrink();
      case SplashPhase.loading:
        return Column(
          children: [
            ClipRRect(
              borderRadius: AppRadius.xsAll,
              child: LinearProgressIndicator(
                value: controller.progress.value,
                minHeight: 10,
                color: AppColors.primary,
                // Visible against the page background, not a faint tint.
                backgroundColor: const Color(0xffC3E8D8),
                trackGap: 0,
                stopIndicatorColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.label.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDarkColor,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: const Color(0xfff7f8f7),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  const Spacer(),
                  Semantics(
                    label: 'Stiksy',
                    image: true,
                    child: Image.asset(
                      'assets/stickers/stiksy-logo.webp',
                      width: 300,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    RemoteContent.settings.value.splashTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.25,
                      color: Color(0xff202724),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    flex: 8,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 4,
                      children:
                          [
                                // A published list may be shorter than the built-in one.
                                if (stickerTemplates.isNotEmpty)
                                  for (final i in [10, 7, 3, 2])
                                    stickerTemplates[i %
                                        stickerTemplates.length],
                              ]
                              .asMap()
                              .entries
                              .map(
                                (entry) => Transform.rotate(
                                  angle: entry.key.isEven ? -0.07 : 0.07,
                                  child: StickerArtwork(
                                    template: entry.value,
                                    showBackground: false,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const Spacer(),
                  Obx(() => _setup(context)),
                  const SizedBox(height: 16),
                  const Text(
                    'MADE FOR YOUR EVERYDAY EXPRESSIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
