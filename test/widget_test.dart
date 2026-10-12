import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/app_widget.dart';
import 'package:stiksy/app/mvvm/view/editor/sticker_editor_view.dart';
import 'package:stiksy/app/custom_widgets/sticker_components.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/mvvm/view_model/home/home_controller.dart';

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
  });
  tearDown(() => Get.reset());

  testWidgets('onboarding, gallery search, preview and favorites work', (
    tester,
  ) async {
    await tester.pumpWidget(const LayerXApp());
    await tester.pumpAndSettle();
    expect(find.text('Trending Templates'), findsNothing);
    expect(find.text('Get started'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Create a sticker'), findsOneWidget);
    expect(find.text('Trending Templates'), findsNothing);
    expect(find.text('Categories'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(Get.find<SharedPreferences>().getBool('stiksy_onboarded'), true);
    await tester.tap(find.text('Templates').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chai first');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('1 templates'), findsOneWidget);
    await tester.ensureVisible(find.byType(TemplateCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TemplateCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Template preview'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Save to favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save to favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Saved to favorites'), findsOneWidget);
    await tester.tap(find.text('Use This Template'));
    await tester.pumpAndSettle();
    expect(find.text('Sticker Editor'), findsOneWidget);
    expect(Get.find<SharedPreferences>().getStringList('stiksy_favorites'), [
      'funny1',
    ]);
  });

  testWidgets('returning user reaches home at a narrow width', (tester) async {
    await Get.find<SharedPreferences>().setBool('stiksy_onboarded', true);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LayerXApp());
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Trending Templates'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Create a sticker'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.tap(find.text('My Packs').last);
    await tester.pumpAndSettle();
    expect(find.text('Your sticker library'), findsOneWidget);
    expect(find.text('Create your first pack'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('editor applies text and supports undo and redo', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: StickerEditorView(template: stickerTemplates[3])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chai time');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Chai time'), findsWidgets);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text(stickerTemplates[3].text), findsWidgets);
    expect(find.text('Chai time'), findsNothing);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(find.text('Chai time'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('filters combine and saved favorites restore', () async {
    final prefs = Get.find<SharedPreferences>();
    final controller = HomeController(prefs);
    controller.tier.value = 'Premium';
    expect(controller.filtered.every((t) => t.premium), true);
    controller.tier.value = 'Free';
    expect(controller.filtered.every((t) => !t.premium), true);
    controller.tier.value = 'All';
    controller.category.value = 'Cricket';
    controller.query.value = 'Chakka';
    expect(controller.filtered.single.id, 'cricket2');
    await controller.toggleFavorite(stickerTemplates.first);
    expect(HomeController(prefs).favorites, ['urdu1']);
    controller.favoritesOnly.value = true;
    expect(controller.filtered, isEmpty);
    await controller.markViewed(stickerTemplates.first);
    await controller.markViewed(stickerTemplates.first);
    expect(controller.recent, ['urdu1']);
  });
}
