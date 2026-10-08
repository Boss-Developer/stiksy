import 'package:flutter/material.dart';

class StiksyCrown extends StatelessWidget {
  const StiksyCrown({super.key, this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CrownPainter()),
  );
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final path = Path()
      ..moveTo(7, 30)
      ..lineTo(3, 12)
      ..lineTo(14, 19)
      ..lineTo(20, 6)
      ..lineTo(26, 19)
      ..lineTo(37, 12)
      ..lineTo(33, 30)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffec5b), Color(0xffffb214)],
        ).createShader(const Rect.fromLTWH(0, 0, 40, 40)),
    );
    final gold = Paint()..color = const Color(0xffffcc28);
    for (final point in [
      const Offset(3, 11),
      const Offset(20, 5),
      const Offset(37, 11),
    ]) {
      canvas.drawCircle(point, 3, gold);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 32, 26, 4),
        const Radius.circular(2),
      ),
      gold,
    );
    canvas.drawCircle(
      const Offset(20, 25),
      2.5,
      Paint()..color = const Color(0xffff6c70),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrownPainter old) => false;
}
