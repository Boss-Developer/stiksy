import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/mvvm/view/export/export_sticker_view.dart';
import 'package:stiksy/app/services/sticker_export_service.dart';
import 'package:stiksy/app/services/template_access.dart';

Future<void> usePrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  Get.put<SharedPreferences>(
    await SharedPreferences.getInstance(),
    permanent: true,
  );
}

Future<Uint8List> greenPng(WidgetTester tester) async {
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
  return png;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  // The welcome gift is used up, so the watermark offer shows.
  setUp(() => usePrefs({'stiksy_clean_stickers_used': 3}));
  tearDown(Get.reset);

  testWidgets('a new user’s first stickers have no watermark', (tester) async {
    await Get.find<SharedPreferences>().remove('stiksy_clean_stickers_used');
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final png = await greenPng(tester);
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExportStickerView(bytes: png, text: 'Chai'),
      ),
    );
    await settle(tester);
    expect(find.text('Watch video'), findsNothing);
    expect(find.textContaining('Welcome gift'), findsOneWidget);
    expect(find.textContaining('2 more free'), findsOneWidget);
  });

  testWidgets('a template unlocked by video has no watermark', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const template = StickerTemplate(
      'gold',
      'Gold',
      'All',
      '',
      '',
      Colors.amber,
      premium: true,
    );
    await TemplateAccess.unlock(template);
    final png = await greenPng(tester);
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExportStickerView(bytes: png, text: 'Chai', template: template),
      ),
    );
    await settle(tester);
    expect(find.text('Watch video'), findsNothing);
    expect(find.textContaining('Welcome gift'), findsNothing);
  });

  testWidgets('export screen leads with one primary action', (tester) async {
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
    // Tests run as Android, where WhatsApp is the primary action.
    expect(find.text('Send to WhatsApp'), findsOneWidget);
    expect(find.text('Add to my sticker pack'), findsOneWidget);
    expect(find.text('Watch video'), findsOneWidget);
    expect(find.text('Copy text'), findsOneWidget);
    expect(find.textContaining('512'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'without WhatsApp installed the primary action is a plain share',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StickerExportService.channel, (call) async {
            switch (call.method) {
              case 'encodeWebP':
                return Uint8List(1024);
              case 'availableWhatsApp':
                return {'whatsapp': false, 'business': false};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StickerExportService.channel, null),
      );
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
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Share sticker'), findsOneWidget);
      expect(find.text('Send to WhatsApp'), findsNothing);
    },
  );
}
