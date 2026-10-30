import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/services/happy_moments.dart';
import 'package:stiksy/app/services/purchase_service.dart';
import 'package:stiksy/app/services/user_messages.dart';

Future<void> openApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const GetMaterialApp(home: Scaffold(body: Text('APP'))),
  );
}

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
    PurchaseService.unlocked.value = false;
  });
  tearDown(Get.reset);

  testWidgets('adding a pack to WhatsApp is celebrated with clear next steps', (
    tester,
  ) async {
    await openApp(tester);
    showPackResult({'status': 'added'});
    await tester.pumpAndSettle();
    expect(find.text('Your pack is on WhatsApp!'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Stay in Stiksy'));
    await tester.pumpAndSettle();
    expect(find.text('Your pack is on WhatsApp!'), findsNothing);
  });

  testWidgets('remove-ads is offered once, only after the 5th sticker', (
    tester,
  ) async {
    await openApp(tester);
    for (var i = 0; i < HappyMoments.upgradeAfter - 1; i++) {
      await HappyMoments.stickerTaken();
    }
    HappyMoments.offerUpgradeIfDue();
    await tester.pumpAndSettle();
    expect(find.text('Remove ads forever'), findsNothing);

    await HappyMoments.stickerTaken();
    HappyMoments.offerUpgradeIfDue();
    await tester.pumpAndSettle();
    expect(find.text('You’ve made 5 stickers!'), findsOneWidget);
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();

    // Never asked twice.
    await HappyMoments.stickerTaken();
    HappyMoments.offerUpgradeIfDue();
    await tester.pumpAndSettle();
    expect(find.text('Remove ads forever'), findsNothing);
  });

  testWidgets('people who already paid are never offered it', (tester) async {
    PurchaseService.unlocked.value = true;
    await openApp(tester);
    for (var i = 0; i < 10; i++) {
      await HappyMoments.stickerTaken();
    }
    HappyMoments.offerUpgradeIfDue();
    await tester.pumpAndSettle();
    expect(find.text('Remove ads forever'), findsNothing);
  });
}
