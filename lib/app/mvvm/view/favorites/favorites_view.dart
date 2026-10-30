import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../model/sticker_template.dart';
import '../../view_model/home/home_controller.dart';

/// Templates the user has hearted. A page of its own (back arrow, no bottom
/// bar), opened from the Favorites card on Home.
class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Your favorites')),
      body: SafeArea(
        child: Obx(() {
          // Rebuilds when a heart is toggled or newly published templates land.
          controller.contentTick.value;
          final saved = [
            for (final t in stickerTemplates)
              if (controller.favorites.contains(t.id)) t,
          ];
          if (saved.isEmpty) return const _Empty();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  TemplateGrid(
                    templates: saved,
                    favorites: controller.favorites.toList(),
                    onTap: (t) {
                      controller.markViewed(t);
                      Get.toNamed(AppRoutes.templatePreview, arguments: t);
                    },
                    onFavorite: controller.toggleFavorite,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 48,
            color: AppColors.textLightBlack,
          ),
          SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the heart on any template to keep it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLightBlack, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
