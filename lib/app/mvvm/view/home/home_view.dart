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
            fontWeight: FontWeight.w800,
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
            color: name == 'All' ? color : color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: name == 'All' ? Colors.white : color),
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
        border: Border.all(color: const Color(0xffebeae3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
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
              color: Color(0xff243d33),
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
            fontSize: 26,
            color: Color(0xff123f31),
            fontWeight: FontWeight.w900,
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
                    'SMALL STICKERS. BIG FEELINGS.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: Color(0xff728077),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Make every chat\na little more you.',
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: -1.2,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                  heading(
                    'Pakistani Sticker Packs',
                    () => Get.to(() => const CatalogView()),
                  ),
                  const Text(
                    '40 packs · download once, use offline',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
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
            border: Border(top: BorderSide(color: Color(0xffebeae3))),
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
    color: const Color(0xff123f31),
    borderRadius: BorderRadius.circular(28),
    child: InkWell(
      onTap: () => Get.to(() => const CustomStickerView()),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR OWN CREATION',
                    style: TextStyle(
                      color: Color(0xffbdd8bf),
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create a sticker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Photo · Emoji · Text',
                    style: TextStyle(color: Color(0xffc2d5c9), fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffe3edba),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Make it yours',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.rotate(
              angle: .12,
              child: Image.asset(
                'assets/stickers/mood-cat.webp',
                width: 95,
                height: 125,
              ),
            ),
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
