import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/mvvm/view/export/export_sticker_view.dart';
import 'package:stiksy/app/mvvm/view/premium/upgrade_view.dart';
import 'package:stiksy/app/services/purchase_service.dart';
import 'package:stiksy/app/services/template_access.dart';

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
  tearDown(() {
    PurchaseService.unlocked.value = false;
    Get.reset();
  });

  testWidgets('upgrade screen sells a one-time purchase, not a subscription', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: UpgradeView()));
    // Past the store lookup timeout, as when Play services never answer.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Remove ads & watermark'), findsOneWidget);
    expect(find.textContaining('No subscription'), findsOneWidget);
    // No store in tests: it explains what to do and offers a retry instead
    // of hanging or showing a dead grey button.
    expect(
      find.textContaining('Google Play couldn’t show the price'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    expect(find.text('Restore purchase'), findsOneWidget);
  });

  testWidgets('owners see a thank-you state', (tester) async {
    PurchaseService.unlocked.value = true;
    await tester.pumpWidget(const GetMaterialApp(home: UpgradeView()));
    await tester.pumpAndSettle();
    expect(find.text('You’re all set'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Restore purchase'), findsNothing);
  });

  testWidgets('owners open premium templates without a video', (tester) async {
    PurchaseService.unlocked.value = true;
    final premium = stickerTemplates.firstWhere((t) => t.premium);
    bool? allowed;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                allowed = await TemplateAccess.allow(context, premium),
            child: const Text('Export'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(allowed, true);
    expect(find.text('Export this premium design'), findsNothing);
  });

  testWidgets('owners get no watermark offer on export', (tester) async {
    PurchaseService.unlocked.value = true;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Uint8List png;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 64, 64),
        Paint()..color = Colors.green,
      );
      final image = await recorder.endRecording().toImage(64, 64);
      png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExportStickerView(bytes: png, text: 'Chai'),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('Your sticker is ready'), findsOneWidget);
    expect(find.text('Watch video'), findsNothing);
    expect(find.text('Remove for good'), findsNothing);
  });

  testWidgets('free users see both ways to remove the watermark', (
    tester,
  ) async {
    // Past the welcome gift of unmarked stickers.
    await Get.find<SharedPreferences>().setInt('stiksy_clean_stickers_used', 3);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Uint8List png;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 64, 64),
        Paint()..color = Colors.green,
      );
      final image = await recorder.endRecording().toImage(64, 64);
      png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExportStickerView(bytes: png, text: 'Chai'),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('Watch video'), findsOneWidget);
    expect(find.text('Remove for good'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
