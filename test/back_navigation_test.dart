import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:stiksy/app/app_widget.dart';
import 'package:stiksy/app/custom_widgets/sticker_components.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/mvvm/view/favorites/favorites_view.dart';
import 'package:stiksy/app/mvvm/view_model/home/home_controller.dart';

import 'fake_paths.dart';

void main() {
  setUp(() async {
    installFakePaths();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'stiksy_onboarded': true});
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
  });
  tearDown(() => Get.reset());

  group('HomeController.onBack', () {
    test('any other tab goes back to the first tab', () {
      final c = HomeController(Get.find<SharedPreferences>());
      for (final tab in [1, 2, 3]) {
        c.tab.value = tab;
        expect(c.onBack(), BackAction.switchedToFirstTab);
        expect(c.tab.value, 0);
      }
    });

    test('the first tab needs two presses within two seconds to exit', () {
      final c = HomeController(Get.find<SharedPreferences>());
      final t0 = DateTime(2026, 10, 23, 12);
      expect(c.onBack(now: t0), BackAction.askToConfirmExit);
      expect(
        c.onBack(now: t0.add(const Duration(milliseconds: 1900))),
        BackAction.exit,
      );
    });

    test('a slow second press only asks again', () {
      final c = HomeController(Get.find<SharedPreferences>());
      final t0 = DateTime(2026, 10, 23, 12);
      expect(c.onBack(now: t0), BackAction.askToConfirmExit);
      final late = t0.add(const Duration(seconds: 3));
      expect(c.onBack(now: late), BackAction.askToConfirmExit);
      // The window restarts from that press.
      expect(
        c.onBack(now: late.add(const Duration(seconds: 1))),
        BackAction.exit,
      );
    });

    test('switching tabs does not count as the first press', () {
      final c = HomeController(Get.find<SharedPreferences>());
      final t0 = DateTime(2026, 10, 23, 12);
      c.tab.value = 2;
      expect(c.onBack(now: t0), BackAction.switchedToFirstTab);
      expect(
        c.onBack(now: t0.add(const Duration(milliseconds: 300))),
        BackAction.askToConfirmExit,
      );
    });
  });

  testWidgets(
    'Favorites is its own page: back arrow, no bottom bar, Back returns Home',
    (tester) async {
      final prefs = Get.find<SharedPreferences>();
      await prefs.setStringList('stiksy_favorites', [
        stickerTemplates.first.id,
      ]);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const LayerXApp());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Create a sticker'), findsOneWidget);
      expect(find.text('My Packs'), findsOneWidget); // bottom bar is there

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Your favorites'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(TemplateCard), findsOneWidget);
      // The bottom bar is not part of this page.
      expect(find.text('My Packs'), findsNothing);
      expect(find.text('Catalog'), findsNothing);

      // The back arrow and the system Back both return to Home.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Create a sticker'), findsOneWidget);
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Create a sticker'), findsOneWidget);
    },
  );

  testWidgets('an empty Favorites page explains how to add some', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(HomeController(Get.find<SharedPreferences>()));
    await tester.pumpWidget(const GetMaterialApp(home: FavoritesView()));
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing); // root route in this test
  });

  testWidgets(
    'the real Back button: first tab asks twice, a second press exits',
    (tester) async {
      final closed = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') closed.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const LayerXApp());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // From another tab, Back goes to the first tab.
      await tester.tap(find.text('My Packs'));
      // That tab shows a loader that never settles, so pump a fixed time.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create a sticker'), findsOneWidget);
      expect(closed, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(closed, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, hasLength(1));

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    },
  );
}
