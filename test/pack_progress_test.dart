import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/view/export/export_sticker_view.dart';
import 'package:stiksy/app/services/sticker_export_service.dart';

String packJson(int count, {String id = 'pack_a'}) => jsonEncode({
  'identifier': id,
  'name': 'My Creations',
  'stickers': List.generate(count, (i) => {'file': 's$i.webp'}),
});

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StickerExportService.channel, null);
    Get.reset();
  });

  Future<void> openExport(
    WidgetTester tester, {
    required List<String> existing,
    required int countAfterAdd,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StickerExportService.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'encodeWebP':
              return Uint8List(1024);
            case 'availableWhatsApp':
              return {'whatsapp': true, 'business': false};
            case 'listPacks':
              return existing;
            case 'createPack':
              return packJson(0);
            case 'addSticker':
              return packJson(countAfterAdd);
          }
          return null;
        });
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
    await tester.tap(find.text('Add to my sticker pack'));
    // The busy loader animates forever, so pumpAndSettle would never return.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('first sticker goes straight in and shows 1 of 3', (
    tester,
  ) async {
    await openExport(tester, existing: [], countAfterAdd: 1);
    // No "which pack?" question for a brand-new user.
    expect(find.text('Which pack?'), findsNothing);
    expect(find.text('Nice! Keep going'), findsOneWidget);
    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(find.text('Make another sticker'), findsOneWidget);
    expect(find.text('Add to WhatsApp'), findsNothing);
  });

  testWidgets('third sticker offers to install the pack', (tester) async {
    await openExport(tester, existing: [packJson(2)], countAfterAdd: 3);
    expect(find.text('Added to My Creations'), findsOneWidget);
    expect(find.text('Add to WhatsApp'), findsOneWidget);
    expect(find.text('Make another sticker'), findsOneWidget);
  });

  testWidgets('several open packs and no history asks which one', (
    tester,
  ) async {
    await openExport(
      tester,
      existing: [
        packJson(1),
        packJson(2, id: 'pack_b'),
      ],
      countAfterAdd: 2,
    );
    expect(find.text('Which pack?'), findsOneWidget);
    expect(find.text('New pack'), findsOneWidget);
  });

  testWidgets(
    'downloaded catalog packs are never offered for your own stickers',
    (tester) async {
      // pack_b is a copy of a catalog pack; it gets rebuilt on updates.
      await Get.find<SharedPreferences>().setString(
        'stiksy_catalog_links',
        jsonEncode({
          'chai': {'local': 'pack_b', 'version': '1'},
        }),
      );
      await openExport(
        tester,
        existing: [
          packJson(1),
          packJson(10, id: 'pack_b'),
        ],
        countAfterAdd: 2,
      );
      // Only one pack of the user's own is left, so it is used directly.
      expect(find.text('Which pack?'), findsNothing);
      expect(find.text('Nice! Keep going'), findsOneWidget);
      expect(find.textContaining('2 of 3'), findsOneWidget);
    },
  );
}
