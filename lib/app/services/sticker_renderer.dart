import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class StickerRenderer {
  /// Bound decode memory and fit imported photos without stretching them.
  static Future<Uint8List> normalizeImage(
    Uint8List bytes, {
    bool cover = false,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? source, output;
    ui.Picture? picture;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = 512 / longest;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 512),
        targetHeight: (descriptor.height * scale).round().clamp(1, 512),
      );
      source = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(0, 0, 512, 512),
        image: source,
        fit: cover ? BoxFit.cover : BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      picture = recorder.endRecording();
      output = await picture.toImage(512, 512);
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Unable to prepare image');
      return data.buffer.asUint8List();
    } finally {
      output?.dispose();
      picture?.dispose();
      source?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<Uint8List> watermark(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(source, Offset.zero, Paint());
    final label = TextPainter(
      text: const TextSpan(
        text: 'Stiksy',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xff07552b),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = Offset(
      source.width - label.width - 18,
      source.height - label.height - 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx - 6,
          position.dy - 3,
          label.width + 12,
          label.height + 6,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xeeffffff),
    );
    label.paint(canvas, position);
    final picture = recorder.endRecording();
    final output = await picture.toImage(source.width, source.height);
    try {
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Unable to render watermark');
      return bytes.buffer.asUint8List();
    } finally {
      label.dispose();
      output.dispose();
      picture.dispose();
      source.dispose();
      codec.dispose();
    }
  }
}
