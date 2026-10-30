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
import 'package:stiksy/app/services/template_access.dart';

import 'fake_paths.dart';

void main() {
  setUp(() async {
    installFakePaths();
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
      await tester.tap(find.text('Arrange'));
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
      list.onReorderItem!(0, 3);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
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
      final draft =
          jsonDecode(
                Get.find<SharedPreferences>()
                    .getStringList('stiksy_drafts')!
                    .single,
              )
              as Map<String, dynamic>;
      final layers = draft['layers'] as List;
      // Text, picture, the added ❤️ and its duplicate: the template brings no
      // extra decorations the preview didn't show.
      expect(layers.length, 4);
      final moved = layers.firstWhere((v) => v['id'] == 'element-0');
      expect(moved['x'], lessThan(256));
      expect(moved['y'], lessThan(338));
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
        expect(
          rgba!.getUint8(3),
          0,
        ); // Checkerboard and selection handles stay outside the export boundary.
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
      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
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
    await tester.tap(find.text('Finish'));
    // Saving touches real files, which only progress outside fake async.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
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
  testWidgets(
    'leaving with unsaved edits asks first; untouched leaves freely',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Get.to(
                  () => StickerEditorView(template: stickerTemplates[3]),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Save your design?'), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);

      await open();
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Save your design?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Sticker Editor'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'premium templates are free to edit and ask for the video at export',
    (tester) async {
      final premium = stickerTemplates.firstWhere((t) => t.premium);
      await tester.pumpWidget(
        GetMaterialApp(home: StickerEditorView(template: premium)),
      );
      await tester.pumpAndSettle();
      // Editing never prompts.
      expect(find.text('Use this premium design'), findsNothing);
      await tester.tap(find.text('Finish'));
      for (var i = 0; i < 30; i++) {
        if (find.text('Use this premium design').evaluate().isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Use this premium design'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Sticker Editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Let the 'Design saved' toast finish so no timer outlives the test.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('an unlocked premium template passes without asking again', (
    tester,
  ) async {
    final premium = stickerTemplates.firstWhere((t) => t.premium);
    await Get.find<SharedPreferences>().setInt(
      'stiksy_template_unlock_${premium.id}',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
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
    expect(find.text('Use this premium design'), findsNothing);
  });
  Widget textEditor() => GetMaterialApp(
    home: StickerEditorView(
      template: stickerTemplates[3],
      initialDesign: {
        'version': 2,
        'layers': [
          {
            'id': 'text-0',
            'kind': 'text',
            'content': 'Hello',
            'x': 256.0,
            'y': 256.0,
            'width': 300.0,
            'height': 200.0,
            'font': 'Poppins',
            'fontSize': 40.0,
          },
        ],
        'selectedId': null,
        'background': 0,
      },
    ),
  );
  bool undoEnabled(WidgetTester tester) =>
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed !=
      null;
  testWidgets('typing folds into one undo step', (tester) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    for (final partial in ['H', 'Hi', 'Hi t', 'Hi there']) {
      await tester.enterText(find.byType(TextField), partial);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsWidgets);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    // One tap undoes the whole word, back to the original text.
    expect(find.text('Hello'), findsWidgets);
    expect(undoEnabled(tester), false);
  });
  testWidgets('double-tapping text types in place; empty canvas deselects', (
    tester,
  ) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    // A design opens with its first item selected, so its controls show.
    expect(find.byTooltip('Bigger text'), findsOneWidget);
    final layer = find.byKey(const ValueKey('canvas-layer-text-0'));
    await tester.tap(layer);
    // Longer than the double-tap window, so this is a plain tap.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // Selecting shows the controls under the canvas.
    expect(find.byTooltip('Bigger text'), findsOneWidget);
    await tester.tap(layer);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(layer);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    final corner = tester.getTopLeft(
      find.byKey(const ValueKey('canvas-empty')),
    );
    await tester.tapAt(corner + const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bigger text'), findsNothing);
    expect(
      find.text('Tap an item to edit it · Double-tap text to type'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('repeated size taps are a single undo step', (tester) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('canvas-layer-text-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bigger text'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Bigger text'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Bigger text'));
    await tester.pumpAndSettle();
    expect(undoEnabled(tester), true);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(undoEnabled(tester), false);
  });

  /// Taps Next and waits for the draft save (real file IO) to finish.
  Future<Map<String, dynamic>> savedDraft(WidgetTester tester) async {
    await tester.tap(find.text('Finish'));
    final prefs = Get.find<SharedPreferences>();
    for (var i = 0; i < 30; i++) {
      if ((prefs.getStringList('stiksy_drafts') ?? []).isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return jsonDecode(prefs.getStringList('stiksy_drafts')!.single)
        as Map<String, dynamic>;
  }

  testWidgets('a style preset sets colour, outline and shadow in one tap', (
    tester,
  ) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Style presets'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a look'), findsOneWidget);
    await tester.tap(find.text('Bold red'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    final layer = (await savedDraft(tester))['layers'][0];
    expect(layer['color'], 0xffef4444);
    expect(layer['outline'], true);
    expect(layer['shadow'], true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('dragging near the middle snaps to the centre line', (
    tester,
  ) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    final layer = find.byKey(const ValueKey('canvas-layer-text-0'));
    // A few pixels off centre: close enough to snap back to exactly 256.
    await tester.drag(layer, const Offset(3, 3));
    await tester.pumpAndSettle();
    final snapped = (await savedDraft(tester))['layers'][0];
    expect(snapped['x'], 256);
    expect(snapped['y'], 256);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('a long drag moves the layer off the centre line', (
    tester,
  ) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('canvas-layer-text-0')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    final moved = (await savedDraft(tester))['layers'][0];
    expect(moved['x'], greaterThan(256));
    expect(moved['y'], 256);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('first-use tip shows once and stays dismissed', (tester) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    expect(find.textContaining('Double-tap text to type'), findsWidgets);
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsNothing);
    expect(
      Get.find<SharedPreferences>().getBool('stiksy_editor_tip_seen'),
      true,
    );
    // A later editor does not show it again.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsNothing);
  });
  testWidgets('an empty canvas offers text, photo and emoji', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: StickerEditorView(
          template: stickerTemplates[3],
          initialDesign: const {
            'version': 2,
            'layers': [],
            'selectedId': null,
            'background': 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start your sticker'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Add emoji'), findsOneWidget);
    await tester.tap(find.text('Add text'));
    await tester.pumpAndSettle();
    // Straight into typing, and the prompt is gone.
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Start your sticker'), findsNothing);
  });
  testWidgets('edits autosave after a pause and leaving needs no prompt', (
    tester,
  ) async {
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bigger text'));
    await tester.pump(const Duration(seconds: 3));
    final prefs = Get.find<SharedPreferences>();
    for (var i = 0; i < 30; i++) {
      if ((prefs.getStringList('stiksy_drafts') ?? []).isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(prefs.getStringList('stiksy_drafts'), hasLength(1));
    // Let the save finish recording that nothing is left unsaved.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    // Nothing unsaved is left, so back leaves without asking.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Save your design?'), findsNothing);
  });
  testWidgets('with no video available a premium export is let through', (
    tester,
  ) async {
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
    await tester.tap(find.text('Watch video'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Ads are not initialised in tests, which counts as "unavailable".
    expect(allowed, true);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
  testWidgets('every text control is on screen at once, no scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(textEditor());
    await tester.pumpAndSettle();
    const controls = [
      'Edit words',
      'Style presets',
      'Font',
      'Smaller text',
      'Bigger text',
      'Text alignment',
      'Outline',
      'More options',
    ];
    final screen = Offset.zero & const Size(320, 640);
    for (final tooltip in controls) {
      final box = find.byTooltip(tooltip);
      expect(box, findsOneWidget, reason: tooltip);
      expect(
        screen.contains(tester.getCenter(box)),
        true,
        reason: '$tooltip is off screen',
      );
      // Nothing may be scrolled away: it must also receive taps.
      expect(box.hitTestable(), findsOneWidget, reason: tooltip);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'dragging an emoji over text moves only the emoji, with no zoom or spin',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          home: StickerEditorView(
            template: stickerTemplates[3],
            initialDesign: {
              'version': 2,
              'layers': [
                {
                  'id': 'text-0',
                  'kind': 'text',
                  'content': 'Hello',
                  'x': 256.0,
                  'y': 256.0,
                  'width': 300.0,
                  'height': 200.0,
                  'font': 'Poppins',
                  'fontSize': 40.0,
                },
                // Sits on the text's resize handle, the worst case.
                {
                  'id': 'emoji-0',
                  'kind': 'emoji',
                  'content': '😀',
                  'x': 400.0,
                  'y': 350.0,
                  'width': 180.0,
                  'height': 180.0,
                },
              ],
              'selectedId': null,
              'background': 0,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final emoji = find.byKey(const ValueKey('canvas-layer-emoji-0'));
      // Several separate one-finger drags, crossing the centre line where the
      // snap guide appears and disappears (that used to scramble touches).
      for (var round = 0; round < 3; round++) {
        final finger = await tester.startGesture(tester.getCenter(emoji));
        for (var i = 0; i < 12; i++) {
          await finger.moveBy(const Offset(-6, -4));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await finger.up();
        await tester.pump(const Duration(seconds: 1));
      }
      final layers = (await savedDraft(tester))['layers'] as List;
      final text = layers.firstWhere((l) => l['id'] == 'text-0');
      final moved = layers.firstWhere((l) => l['id'] == 'emoji-0');
      expect(moved['x'], lessThan(400));
      expect(moved['scale'], 1);
      expect(moved['rotation'], 0);
      // The text underneath, and its handles, were never touched.
      expect(text['x'], 256);
      expect(text['y'], 256);
      expect(text['scale'], 1);
      expect(text['rotation'], 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets('all editor panels fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(home: StickerEditorView(template: stickerTemplates[3])),
    );
    await tester.pumpAndSettle();
    for (final label in ['Text', 'Background', 'Arrange', 'Stickers']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
    }
  });
}
