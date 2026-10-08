import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/view/editor/sticker_editor_view.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/services/sticker_export_service.dart';

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
  testWidgets(
    'multiple layers duplicate, lock and reorder; export omits selection controls',
    (tester) async {
      Uint8List? exported;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StickerExportService.channel, (call) async {
            if (call.method == 'encodeWebP') {
              exported = (call.arguments as Map)['png'];
              return exported;
            }
            if (call.method == 'availableWhatsApp') {
              return {'whatsapp': false, 'business': true};
            }
            return null;
          });
      await tester.pumpWidget(
        GetMaterialApp(home: StickerEditorView(template: stickerTemplates[3])),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('canvas-layer-element-0')),
        const Offset(-30, -20),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('❤️'));
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Layers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      final delete = find.widgetWithText(TextButton, 'Delete');
      expect(tester.widget<TextButton>(delete).onPressed, isNull);
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderItem!(0, 4);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      for (int i = 0; i < 20 && exported == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final draft = jsonDecode(
        Get.find<SharedPreferences>().getStringList('stiksy_drafts')!.single,
      ) as Map<String, dynamic>;
      final layers = draft['layers'] as List;
      expect(layers.length, 5);
      final moved = layers.firstWhere((v) => v['id'] == 'element-0');
      expect(moved['x'], lessThan(375));
      expect(moved['y'], lessThan(375));
      expect(layers.last['kind'], 'text');
      expect(layers.where((v) => v['locked']).length, 1);
      expect(exported, isNotNull);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(exported!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgba!.getUint8(3), 0); // Checkerboard and selection handles stay outside the export boundary.
        frame.image.dispose();
        codec.dispose();
      });
      Get.back();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        GetMaterialApp(
          home: StickerEditorView(
            template: stickerTemplates[3],
            initialDesign: draft,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Layers'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(5));
    },
  );
  testWidgets('legacy drafts migrate and gradient background persists', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: StickerEditorView(
          template: stickerTemplates[3],
          initialDesign: {
            'text': 'Saved chai',
            'emoji': '☕',
            'size': 36.0,
            'background': 0,
            'alignment': 2,
            'locked': false,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved chai'), findsWidgets);
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradient'));
    await tester.pumpAndSettle();
    final red = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 38 &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xffef4444),
    );
    await tester.tap(red.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final draft = jsonDecode(
      Get.find<SharedPreferences>().getStringList('stiksy_drafts')!.single,
    );
    expect(draft['version'], 2);
    expect(draft['backgroundMode'], 1);
    expect(draft['background'], 0xffef4444);
    expect((draft['layers'] as List).first['content'], 'Saved chai');
    expect(tester.takeException(), isNull);
  });
  testWidgets('all editor panels fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(home: StickerEditorView(template: stickerTemplates[3])),
    );
    await tester.pumpAndSettle();
    for (final label in ['Text', 'Background', 'Layers', 'Stickers']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
    }
  });
}
