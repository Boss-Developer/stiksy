// Run with: flutter test --no-pub tools/render_sticker_catalog_test.dart
// Uses Flutter's native font shaping and painting rather than image-generated text.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const palettes = [
  [Color(0xff153e32), Color(0xffe8bd59), Color(0xfffff2d9)],
  [Color(0xff653c25), Color(0xffde9153), Color(0xffffeed9)],
  [Color(0xff563347), Color(0xffef94ae), Color(0xffffe9f0)],
  [Color(0xff264a61), Color(0xff7ac4d1), Color(0xffe5f4f7)],
  [Color(0xff51462e), Color(0xffc4b873), Color(0xfff6f0d6)],
];

void sparkle(Canvas canvas, Offset point, double radius, Color color) {
  final p = Path();
  for (int i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    final r = i.isEven ? radius : radius * .3;
    final x = point.dx + math.cos(a) * r;
    final y = point.dy + math.sin(a) * r;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  canvas.drawPath(p..close(), Paint()..color = color);
}

void caption(
  Canvas c,
  String text,
  Rect rect,
  Color color, {
  double maxSize = 49,
  bool outline = true,
  double rotation = 0,
}) {
  TextPainter make(double size, {bool stroke = false}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        fontSize: size,
        height: 1.06,
        letterSpacing: -.9,
        color: stroke ? null : color,
        foreground: stroke
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 9
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white)
            : null,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: rect.width);
  double size = maxSize;
  var tp = make(size);
  while ((tp.height > rect.height || tp.didExceedMaxLines) && size > 23) {
    size -= 1;
    tp.dispose();
    tp = make(size);
  }
  if (tp.height > rect.height) {
    throw StateError('Caption does not fit: $text');
  }
  c.save();
  c.translate(rect.center.dx, rect.center.dy);
  c.rotate(rotation);
  final origin = Offset(-tp.width / 2, -tp.height / 2);
  if (outline) {
    final stroke = make(size, stroke: true);
    stroke.paint(c, origin);
    stroke.dispose();
  }
  tp.paint(c, origin);
  tp.dispose();
  c.restore();
}

void illustration(Canvas canvas, ui.Image image, Rect bounds, double rotation) {
  final aspect = image.width / image.height;
  double w = bounds.width, h = w / aspect;
  if (h > bounds.height) {
    h = bounds.height;
    w = h * aspect;
  }
  canvas.save();
  canvas.translate(bounds.center.dx, bounds.center.dy);
  canvas.rotate(rotation);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}

Future<void> render(
  Map<String, dynamic> pack,
  ui.Image art,
  int index,
  String destination,
) async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final palette = palettes[((pack['number'] as int) + index) % palettes.length];
  final ink = palette[0], accent = palette[1], paper = palette[2];
  final text = (pack['captions'] as List)[index] as String;
  final angle = (index.isEven ? -1 : 1) * .04;
  Rect artRect = const Rect.fromLTWH(88, 124, 336, 324),
      textRect = const Rect.fromLTWH(38, 24, 436, 130);
  final bg = Paint()..color = paper;
  switch (index) {
    case 0:
      artRect = const Rect.fromLTWH(78, 155, 356, 320);
      textRect = const Rect.fromLTWH(32, 26, 448, 145);
    case 1:
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(35, 25, 442, 172),
          const Radius.circular(42),
        ),
        Paint()..color = Colors.white,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(43, 33, 426, 156),
          const Radius.circular(35),
        ),
        bg,
      );
      c.drawPath(
        Path()
          ..moveTo(330, 174)
          ..lineTo(359, 223)
          ..lineTo(397, 174)
          ..close(),
        Paint()..color = Colors.white,
      );
      artRect = const Rect.fromLTWH(72, 179, 368, 296);
      textRect = const Rect.fromLTWH(64, 47, 384, 121);
    case 2:
      artRect = const Rect.fromLTWH(83, 18, 346, 320);
      textRect = const Rect.fromLTWH(44, 346, 424, 115);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(25, 330, 462, 145),
          const Radius.circular(36),
        ),
        Paint()..color = Colors.white,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(33, 338, 446, 129),
          const Radius.circular(29),
        ),
        bg,
      );
    case 3:
      final burst = Path();
      for (int i = 0; i < 32; i++) {
        final a = i * math.pi / 16;
        final r = i.isEven ? 218.0 : 203.0;
        final x = 256 + math.cos(a) * r, y = 242 + math.sin(a) * r;
        if (i == 0) {
          burst.moveTo(x, y);
        } else {
          burst.lineTo(x, y);
        }
      }
      c.drawPath(burst..close(), Paint()..color = Colors.white);
      artRect = const Rect.fromLTWH(90, 45, 332, 302);
      textRect = const Rect.fromLTWH(42, 340, 428, 126);
    case 4:
      artRect = const Rect.fromLTWH(101, 154, 310, 307);
      textRect = const Rect.fromLTWH(40, 31, 432, 142);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(37, 33, 438, 148),
          const Radius.circular(48),
        ),
        Paint()..color = Colors.white,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(45, 41, 422, 132),
          const Radius.circular(40),
        ),
        bg,
      );
    case 5:
      artRect = const Rect.fromLTWH(15, 153, 278, 302);
      textRect = const Rect.fromLTWH(264, 101, 211, 265);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(246, 83, 249, 302),
          const Radius.circular(38),
        ),
        Paint()..color = Colors.white,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(254, 91, 233, 286),
          const Radius.circular(30),
        ),
        bg,
      );
    case 6:
      artRect = const Rect.fromLTWH(81, 21, 350, 325);
      textRect = const Rect.fromLTWH(43, 339, 426, 134);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 324, 468, 158),
          const Radius.circular(45),
        ),
        Paint()..color = Colors.white,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(30, 332, 452, 142),
          const Radius.circular(37),
        ),
        Paint()..color = accent,
      );
    case 7:
      artRect = const Rect.fromLTWH(131, 157, 351, 313);
      textRect = const Rect.fromLTWH(31, 33, 410, 159);
      c.drawOval(
        const Rect.fromLTWH(16, 16, 451, 199),
        Paint()..color = Colors.white,
      );
      c.drawOval(const Rect.fromLTWH(24, 24, 435, 183), bg);
    case 8:
      artRect = const Rect.fromLTWH(41, 145, 360, 319);
      textRect = const Rect.fromLTWH(37, 26, 438, 154);
    case 9:
      artRect = const Rect.fromLTWH(85, 21, 342, 326);
      textRect = const Rect.fromLTWH(36, 338, 440, 136);
  }
  sparkle(c, const Offset(54, 246), 15, accent);
  sparkle(c, const Offset(449, 263), 18, accent);
  sparkle(c, const Offset(420, 449), 12, accent);
  illustration(c, art, artRect, angle);
  caption(
    c,
    text,
    textRect,
    ink,
    maxSize: index == 5 ? 35 : 49,
    outline: index == 0 || index == 3 || index == 8 || index == 9,
    rotation: index == 8 ? -.07 : 0,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 512);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  testWidgets('render server catalog', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Poppins');
      loader.addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
      await loader.load();
      final plan = jsonDecode(
        await File('content/sticker-catalog-source/plan.json').readAsString(),
      ) as List;
      final source = jsonDecode(
        await File('content/sticker-catalog-source/generated-art.json')
            .readAsString(),
      ) as List;
      final limit =
          int.tryParse(Platform.environment['STIKSY_RENDER_PACKS'] ?? '40') ??
          40;
      for (final value in plan.where((p) => p['number'] <= limit)) {
        final pack = Map<String, dynamic>.from(value);
        final asset = source.singleWhere((v) => v['number'] == pack['number']);
        final codec = await ui.instantiateImageCodec(
          await File(asset['preparedPath']).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        final dir = Directory(
          'build/sticker-catalog-renders/${pack['folder']}',
        );
        await dir.create(recursive: true);
        for (int n = 0; n < 10; n++) {
          await render(
            pack,
            frame.image,
            n,
            '${dir.path}/${(n + 1).toString().padLeft(2, '0')}.png',
          );
        }
        frame.image.dispose();
        codec.dispose();
        debugPrint('Rendered ${pack['number']}/40: ${pack['title']}');
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
