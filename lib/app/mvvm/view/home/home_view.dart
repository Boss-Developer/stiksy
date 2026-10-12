import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../../custom_widgets/stiksy_ads.dart';
import '../../../custom_widgets/stiksy_crown.dart';
import '../../model/sticker_template.dart';
import '../../view_model/home/home_controller.dart';
import '../catalog/catalog_view.dart';
import '../create/custom_sticker_view.dart';
import '../premium/premium_view.dart';
import '../packs/sticker_packs_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});
  void preview(StickerTemplate t) {
    controller.markViewed(t);
    Get.toNamed(AppRoutes.templatePreview, arguments: t);
  }

  Widget heading(String title, VoidCallback action) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            letterSpacing: -.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      TextButton(
        onPressed: action,
        child: const Text(
          'See All',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Obx(
    () => Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Stiksy',
            controller.category.value == 'Urdu'
                ? 'Urdu Calligraphy'
                : controller.category.value == 'All'
                ? 'Templates'
                : controller.category.value,
            'Your favorites',
          ][controller.tab.value],
          style: const TextStyle(
            fontSize: 24,
            color: AppColors.textDarkColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Premium',
            onPressed: () => Get.to(() => const PremiumView()),
            icon: const StiksyCrown(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              children: [
                if (controller.tab.value == 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'A little more you.',
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Turn everyday moments into stickers worth sending.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textLightBlack,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _creatorCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _shortcut(
                          'My packs',
                          'Your sticker collection',
                          Icons.collections_bookmark_outlined,
                          const Color(0xffeeeafa),
                          () => Get.to(() => const StickerPacksView()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _shortcut(
                          'Favorites',
                          '${controller.favorites.length} saved templates',
                          Icons.favorite_border_rounded,
                          const Color(0xffffede8),
                          () => controller.tab.value = 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Made for your conversations',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _catalogCard(),
                  const SizedBox(height: 16),
                  _templateLink(),
                  if (controller.recent.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    heading('Recently viewed', () => controller.tab.value = 1),
                    TemplateGrid(
                      templates: stickerTemplates
                          .where((t) => controller.recent.contains(t.id))
                          .take(4)
                          .toList(),
                      favorites: controller.favorites.toList(),
                      onTap: preview,
                      onFavorite: controller.toggleFavorite,
                    ),
                  ],
                ] else if (controller.tab.value == 1) ...[
                  _templateHero(),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: (v) => controller.query.value = v,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLightBlack,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: ['All', 'Free', 'Premium']
                          .map(
                            (tier) => Expanded(
                              child: Semantics(
                                selected: controller.tier.value == tier,
                                child: Material(
                                  color: controller.tier.value == tier
                                      ? const Color(0xff163e32)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(9),
                                    onTap: () => controller.tier.value = tier,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                      ),
                                      child: Text(
                                        tier,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: controller.tier.value == tier
                                              ? Colors.white
                                              : AppColors.textLightBlack,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${controller.filtered.length} templates',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLightBlack,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Favorites only',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => controller.favoritesOnly.toggle(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  controller.favoritesOnly.value
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: controller.favoritesOnly.value
                                      ? AppColors.primary
                                      : AppColors.textLightBlack,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: controller.favoritesOnly.value
                                        ? AppColors.primary
                                        : AppColors.textLightBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const StiksyAd(),
                  const SizedBox(height: 16),
                  TemplateGrid(
                    templates: controller.filtered,
                    favorites: controller.favorites.toList(),
                    onTap: preview,
                    onFavorite: controller.toggleFavorite,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  TemplateGrid(
                    templates: stickerTemplates
                        .where((t) => controller.favorites.contains(t.id))
                        .toList(),
                    favorites: controller.favorites.toList(),
                    onTap: preview,
                    onFavorite: controller.toggleFavorite,
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xffe5e9e6))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                [
                      nav('Home', Icons.home_outlined, 0),
                      nav('Templates', Icons.style_outlined, 1),
                      FloatingActionButton.small(
                        heroTag: 'create',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        tooltip: 'Create sticker',
                        onPressed: () =>
                            Get.to(() => const CustomStickerView()),
                        child: const Icon(Icons.add, size: 30),
                      ),
                      InkWell(
                        onTap: () => Get.to(() => const StickerPacksView()),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_outlined, size: 23),
                              SizedBox(height: 4),
                              Text('My Packs', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'Stiksy',
                          applicationVersion: '1.0',
                          children: const [
                            Text(
                              'Create Pakistani-inspired stickers offline. Your favorites and designs stay on this device.',
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_outlined, size: 23),
                              SizedBox(height: 4),
                              Text('Settings', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ]
                    .map(
                      (item) => Expanded(
                        child: FittedBox(fit: BoxFit.scaleDown, child: item),
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    ),
  );
  Widget _templateHero() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff203f35), Color(0xff10291f)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff365548)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: Color(0xffd7c493)),
            SizedBox(width: 8),
            Text(
              'THE TEMPLATE STUDIO',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
                color: Color(0xffd7c493),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Small canvas.\nEndless expression.',
          style: TextStyle(
            fontSize: 30,
            height: 1.12,
            letterSpacing: -.8,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Beautiful beginnings for your next sticker.',
          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xffafc8ba)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 100,
          child: Row(
            children: [3, 2, 7]
                .asMap()
                .entries
                .map(
                  (entry) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Transform.rotate(
                        angle: (entry.key - 1) * .10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: [
                              const Color(0xfff5e8ce),
                              const Color(0xffe3eedb),
                              const Color(0xffe9e3f3),
                            ][entry.key],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .15),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: StickerArtwork(
                            template: stickerTemplates[entry.value],
                            showBackground: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xffd7c493), size: 14),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Pick it. Personalize it. Send it.',
                style: TextStyle(color: Color(0xffafc8ba), fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _creatorCard() => Material(
    color: const Color(0xff123f31),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Get.to(() => const CustomStickerView()),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR MINI CREATIVE STUDIO',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: Color(0xffb9d5c4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Create a sticker',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.15,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Your photo. Your words.\nYour kind of fun.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xffc8ded1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: .1,
                  child: Image.asset(
                    'assets/stickers/mood-cat.webp',
                    width: 76,
                    height: 106,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xffe0edb9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Start creating',
                      style: TextStyle(
                        color: Color(0xff123f31),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 18),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xff123f31),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _shortcut(
    String title,
    String subtitle,
    IconData icon,
    Color tint,
    VoidCallback action,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.textDarkColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textLightBlack,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _catalogCard() => Material(
    color: const Color(0xfff0e8da),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: () => Get.to(() => const CatalogView()),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: Color(0xff82663b),
                ),
                SizedBox(width: 8),
                Text(
                  'DESI AT HEART',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: Color(0xff82663b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Pakistani Sticker Packs',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A little chai, a little drama, a lot of expression.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xff7a7062),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 86,
                    child: Row(
                      children: [3, 7, 2]
                          .map(
                            (i) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: StickerArtwork(
                                  template: stickerTemplates[i],
                                  showBackground: false,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textDarkColor,
                  child: Icon(Icons.arrow_forward_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Explore catalog · Save and use offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xff82663b),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _templateLink() => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const Icon(
        Icons.dashboard_customize_outlined,
        color: AppColors.primary,
      ),
      title: const Text(
        'Need a starting point?',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Browse ready-to-edit templates',
        style: TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => controller.openCategory('All'),
    ),
  );

  Widget nav(String title, IconData icon, int index) => InkWell(
    onTap: () => controller.tab.value = index,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 23,
            color: controller.tab.value == index
                ? AppColors.primary
                : Colors.black54,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: controller.tab.value == index
                  ? AppColors.primary
                  : Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );
}
