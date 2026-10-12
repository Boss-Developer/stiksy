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
  Widget miniCategory(String name, IconData icon, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: () => controller.openCategory(name),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: name == 'All' ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: name == 'All' ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                name == 'Political satire'
                    ? 'Political'
                    : name == 'Eid / Ramadan'
                    ? 'Eid'
                    : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: name == 'All' ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget category(String name, IconData icon, Color color) => InkWell(
    onTap: () => controller.openCategory(name),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe5e9e6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 23),
          ),
          const SizedBox(height: 7),
          Text(
            name == 'Urdu'
                ? 'Urdu\nCalligraphy'
                : name == 'Cricket'
                ? 'Cricket\nMemes'
                : name == 'Political satire'
                ? 'Political\nSatire'
                : name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDarkColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
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
                  const Text(
                    'Stickers for every mood.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  _creatorCard(),
                  const SizedBox(height: 24),
                ],
                if (controller.tab.value != 2) ...[
                  TextField(
                    onChanged: (v) {
                      controller.query.value = v;
                      if (v.isNotEmpty) controller.tab.value = 1;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (controller.tab.value == 0)
                    SizedBox(
                      height: 66,
                      child: Row(
                        children: [
                          miniCategory(
                            'All',
                            Icons.public,
                            const Color(0xff059669),
                          ),
                          miniCategory(
                            'Urdu',
                            Icons.draw_outlined,
                            const Color(0xff3b67dc),
                          ),
                          miniCategory(
                            'Cricket',
                            Icons.sports_cricket,
                            const Color(0xff039755),
                          ),
                          miniCategory(
                            'Political satire',
                            Icons.campaign_outlined,
                            const Color(0xffef4c64),
                          ),
                          miniCategory(
                            'Eid / Ramadan',
                            Icons.mosque_outlined,
                            const Color(0xfff18c30),
                          ),
                        ],
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: templateCategories
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: controller.category.value == c,
                                  onSelected: (_) => controller.openCategory(c),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
                if (controller.tab.value == 0) ...[
                  heading(
                    'Trending Templates',
                    () => controller.openCategory('All'),
                  ),
                  SizedBox(
                    height: 184,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = stickerTemplates[[3, 0, 7, 2][i]];
                        return SizedBox(
                          width:
                              (MediaQuery.sizeOf(context).width.clamp(0, 400) -
                                  56) /
                              3,
                          child: InkWell(
                            onTap: () => preview(t),
                            child: Column(
                              children: [
                                StickerArtwork(template: t),
                                const SizedBox(height: 6),
                                Text(
                                  t.title,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(
                      Icons.collections_bookmark_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Pakistani Sticker Packs'),
                    subtitle: const Text('Download and use offline'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Get.to(() => const CatalogView()),
                  ),
                  const SizedBox(height: 12),
                  heading('Categories', () => controller.openCategory('All')),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      category(
                        'Urdu',
                        Icons.draw_outlined,
                        const Color(0xffd89b56),
                      ),
                      category(
                        'Cricket',
                        Icons.sports_cricket,
                        const Color(0xff087353),
                      ),
                      category(
                        'Political satire',
                        Icons.campaign_outlined,
                        const Color(0xffed4b4b),
                      ),
                      category(
                        'Wedding',
                        Icons.card_giftcard,
                        const Color(0xffff8288),
                      ),
                      category(
                        'Eid / Ramadan',
                        Icons.nights_stay_outlined,
                        const Color(0xff2685d9),
                      ),
                      category(
                        'Funny',
                        Icons.sentiment_very_satisfied,
                        const Color(0xffe8b33d),
                      ),
                    ],
                  ),
                  if (controller.recent.isNotEmpty) ...[
                    heading(
                      'Recently viewed',
                      () => controller.openCategory('All'),
                    ),
                    TemplateGrid(
                      templates: stickerTemplates
                          .where((t) => controller.recent.contains(t.id))
                          .toList(),
                      favorites: controller.favorites.toList(),
                      onTap: preview,
                      onFavorite: controller.toggleFavorite,
                    ),
                  ],
                ] else if (controller.tab.value == 1) ...[
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'All', label: Text('All')),
                      ButtonSegment(value: 'Free', label: Text('Free')),
                      ButtonSegment(value: 'Premium', label: Text('Premium')),
                    ],
                    selected: {controller.tier.value},
                    onSelectionChanged: (v) => controller.tier.value = v.first,
                  ),
                  const SizedBox(height: 12),
                  FilterChip(
                    label: const Text('Favorites only'),
                    selected: controller.favoritesOnly.value,
                    onSelected: (v) => controller.favoritesOnly.value = v,
                  ),
                  const StiksyAd(),
                  Text(
                    '${controller.filtered.length} templates',
                    style: const TextStyle(color: Colors.black54),
                  ),
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
  Widget _creatorCard() => Material(
    color: AppColors.primaryLight.withValues(alpha: .45),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: () => Get.to(() => const CustomStickerView()),
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a sticker',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Start with a photo, emoji or text',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
          ],
        ),
      ),
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
