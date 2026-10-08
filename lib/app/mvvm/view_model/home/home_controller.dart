import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/sticker_template.dart';

class HomeController extends GetxController {
  HomeController(this.preferences) {
    favorites.addAll(preferences.getStringList('stiksy_favorites') ?? []);
    recent.addAll(preferences.getStringList('stiksy_recent') ?? []);
  }
  final SharedPreferences preferences;
  final tab = 0.obs;
  final category = 'All'.obs;
  final query = ''.obs;
  final tier = 'All'.obs;
  final favorites = <String>[].obs;
  final recent = <String>[].obs;
  final favoritesOnly = false.obs;
  List<StickerTemplate> get filtered => stickerTemplates
      .where(
        (t) =>
            (category.value == 'All' || t.category == category.value) &&
            (tier.value == 'All' ||
                (tier.value == 'Premium' ? t.premium : !t.premium)) &&
            (!favoritesOnly.value || favorites.contains(t.id)) &&
            '${t.title} ${t.category} ${t.text}'.toLowerCase().contains(
              query.value.toLowerCase(),
            ),
      )
      .toList();
  Future<void> toggleFavorite(StickerTemplate template) async {
    if (favorites.contains(template.id)) {
      favorites.remove(template.id);
    } else {
      favorites.add(template.id);
    }
    await preferences.setStringList('stiksy_favorites', favorites.toList());
  }

  Future<void> markViewed(StickerTemplate template) async {
    recent.remove(template.id);
    recent.insert(0, template.id);
    await preferences.setStringList('stiksy_recent', recent.take(12).toList());
  }

  void openCategory(String value) {
    category.value = value;
    tab.value = 1;
  }
}
