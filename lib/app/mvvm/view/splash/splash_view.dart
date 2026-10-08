import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../custom_widgets/sticker_components.dart';
import '../../model/sticker_template.dart';
import '../../view_model/splash/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff087653), Color(0xff092d24)],
        ),
      ),
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
                  const Text(
                    'Type Anything\nMake it a Sticker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.25,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
                                stickerTemplates[10],
                                stickerTemplates[7],
                                stickerTemplates[3],
                                stickerTemplates[2],
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
                  const Text(
                    'MADE FOR YOUR EVERYDAY EXPRESSIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
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
