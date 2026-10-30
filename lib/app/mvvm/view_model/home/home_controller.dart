import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_gate.dart';
import '../../../services/remote_content.dart';
import '../../model/sticker_template.dart';

/// What the Back button should do on the Home screen.
enum BackAction { switchedToFirstTab, askToConfirmExit, exit }

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

  static const exitWindow = Duration(seconds: 2);
  DateTime? _lastBack;

  /// Back from any other tab returns to the first one; on the first tab it
  /// takes two presses within [exitWindow] to leave the app.
  BackAction onBack({DateTime? now}) {
    if (tab.value != 0) {
      tab.value = 0;
      return BackAction.switchedToFirstTab;
    }
    final at = now ?? DateTime.now();
    final last = _lastBack;
    if (last != null && at.difference(last) < exitWindow) {
      return BackAction.exit;
    }
    _lastBack = at;
    return BackAction.askToConfirmExit;
  }

  RemoteSettings get s {
    contentTick.value;
    return RemoteContent.settings.value;
  }

  List<String> get categories {
    contentTick.value;
    return templateCategories;
  }

  final contentTick = 0.obs;
  void _onContent() {
    contentTick.value++;
    AppGate.check();
  }

  @override
  void onReady() {
    super.onReady();
    AppGate.check();
  }

  @override
  void onInit() {
    super.onInit();
    RemoteContent.revision.addListener(_onContent);
  }

  @override
  void onClose() {
    RemoteContent.revision.removeListener(_onContent);
    super.onClose();
  }

  List<StickerTemplate> get filtered => (contentTick.value, stickerTemplates).$2
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
