import 'package:flutter/material.dart';

class StickerPatternPainter extends CustomPainter {
  const StickerPatternPainter(this.pattern, this.color);
  final int pattern;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = 3;
    for (double y = -24; y < size.height + 24; y += 32) {
      for (double x = -24; x < size.width + 24; x += 32) {
        switch (pattern) {
          case 1:
            canvas.drawCircle(Offset(x, y), 4, paint);
          case 2:
            paint.style = PaintingStyle.stroke;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y), width: 18, height: 18),
                const Radius.circular(4),
              ),
              paint,
            );
          case 3:
            canvas.drawLine(Offset(x, y), Offset(x + 18, y + 18), paint);
          case 4:
            paint.style = PaintingStyle.stroke;
            canvas.drawCircle(Offset(x, y), 10, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(StickerPatternPainter old) =>
      old.pattern != pattern || old.color != color;
}
