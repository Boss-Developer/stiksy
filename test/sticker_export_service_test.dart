import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiksy/app/services/sticker_export_service.dart';
import 'package:stiksy/app/services/sticker_renderer.dart';

LocalStickerPack pack(int count) => LocalStickerPack.fromJson(
  jsonEncode({
    'identifier': 'pack_test',
    'name': 'Test pack',
    'stickers': List.generate(count, (i) => {'file': 's$i.webp'}),
  }),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StickerExportService.channel, null),
  );
  test('incomplete packs cannot launch WhatsApp', () async {
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StickerExportService.channel, (_) async {
          invoked = true;
          return null;
        });
    await expectLater(
      StickerExportService.addToWhatsApp(pack(2)),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'pack_count'),
      ),
    );
    expect(invoked, false);
  });
  test(
    'complete packs pass identifier and Business destination to Android',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StickerExportService.channel, (call) async {
            received = call;
            return {'status': 'added', 'message': ''};
          });
      expect(
        (await StickerExportService.addToWhatsApp(
          pack(3),
          business: true,
        ))['status'],
        'added',
      );
      expect(received!.method, 'addToWhatsApp');
      expect(received!.arguments, {'id': 'pack_test', 'business': true});
    },
  );
  test('oversized native WebP is rejected rather than shared', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          StickerExportService.channel,
          (_) async => Uint8List(100 * 1024),
        );
    await expectLater(
      StickerExportService.encode(Uint8List(1)),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'invalid_webp'),
      ),
    );
  });
  test(
    'saved pack metadata restores and full packs are marked correctly',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            StickerExportService.channel,
            (_) async => [jsonEncode(pack(30).data), jsonEncode(pack(1).data)],
          );
      final restored = await StickerExportService.packs();
      expect(restored.first.count, 30);
      expect(restored.first.ready, true);
      expect(restored.last.ready, false);
    },
  );
  testWidgets(
    'watermark preserves 512px transparent canvas and stamps the footer',
    (tester) async {
      await tester.runAsync(() async {
        final input = File('test/fixtures/transparent-sticker.png')
            .readAsBytesSync();
        final marked = await StickerRenderer.watermark(input);
        final codec = await ui.instantiateImageCodec(marked);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 512);
        expect(image.height, 512);
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(rgba[3], 0);
        bool hasFooter = false;
        for (var y = 470; y < 512; y++) {
          for (var x = 400; x < 512; x++) {
            if (rgba[(y * 512 + x) * 4 + 3] > 0) hasFooter = true;
          }
        }
        expect(hasFooter, true);
        image.dispose();
        codec.dispose();
      });
    },
  );
  testWidgets(
    'photo imports preserve aspect ratio and backgrounds crop to fill',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 512, 128),
          ui.Paint()..color = const ui.Color(0xff009b69),
        );
        final picture = recorder.endRecording();
        final source = await picture.toImage(512, 128);
        final input = (await source.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        for (final cover in [false, true]) {
          final normalized = await StickerRenderer.normalizeImage(
            input,
            cover: cover,
          );
          final codec = await ui.instantiateImageCodec(normalized);
          final image = (await codec.getNextFrame()).image;
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          expect(image.width, 512);
          expect(image.height, 512);
          expect(rgba[3], cover ? 255 : 0);
          expect(rgba[(256 * 512 + 256) * 4 + 3], 255);
          expect(rgba[(160 * 512 + 256) * 4 + 3], cover ? 255 : 0);
          image.dispose();
          codec.dispose();
        }
        source.dispose();
        picture.dispose();
      });
    },
  );
}
