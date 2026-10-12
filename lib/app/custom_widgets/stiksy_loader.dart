import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Branded loading animation with compact and determinate variants.
class StiksyLoader extends StatefulWidget {
  const StiksyLoader({
    super.key,
    this.label,
    this.compact = false,
    this.color = AppColors.primary,
    this.value,
  });

  final String? label;
  final bool compact;
  final Color color;
  final double? value;

  @override
  State<StiksyLoader> createState() => _StiksyLoaderState();
}

class _StiksyLoaderState extends State<StiksyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncAnimation();
  }

  @override
  void didUpdateWidget(covariant StiksyLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAnimation();
  }

  void syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context) || widget.value != null) {
      animation.stop();
      animation.value = 0;
    } else if (!animation.isAnimating) {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label ?? 'Loading',
    value: widget.value == null
        ? null
        : '${(widget.value!.clamp(0, 1) * 100).round()}%',
    liveRegion: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final orb = RepaintBoundary(
            child: CustomPaint(
              size: Size.square(widget.compact ? 24 : 80),
              painter: _OrbitPainter(
                phase: animation.value,
                color: widget.color,
                compact: widget.compact,
              ),
            ),
          );
          if (widget.compact) {
            if (widget.value != null) {
              return SizedBox(
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: widget.value!.clamp(0, 1)),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    builder: (_, value, _) => LayoutBuilder(
                      builder: (_, constraints) => Stack(
                        children: [
                          Container(color: widget.color.withValues(alpha: .12)),
                          SizedBox(
                            width: constraints.maxWidth * value,
                            child: Container(color: widget.color),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return SizedBox(height: 24, child: Center(child: orb));
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              orb,
              if (widget.label != null) ...[
                const SizedBox(height: 24),
                Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLightBlack,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

/// Two fine arcs counter-rotate around a softly breathing center.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.phase,
    required this.color,
    required this.compact,
  });
  final double phase;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .4;
    final turn = phase * math.pi * 2;
    final pulse = (1 - math.cos(turn)) / 2;
    if (!compact) {
      canvas.drawCircle(
        center,
        radius * 1.2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .10 + pulse * .04),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2)),
      );
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = compact ? 1.8 : 2.6;
    final outer = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      stroke..color = color.withValues(alpha: .09),
    );
    stroke.shader = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 1.35,
      colors: [color.withValues(alpha: .08), color],
      transform: GradientRotation(turn),
    ).createShader(outer);
    canvas.drawArc(outer, turn, math.pi * 1.35, false, stroke);
    stroke.shader = null;
    stroke.color = color.withValues(alpha: .45);
    stroke.strokeWidth = compact ? 1.4 : 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * .72),
      -turn + math.pi,
      math.pi * .85,
      false,
      stroke,
    );
    canvas.drawCircle(
      center,
      (compact ? 2 : 5) * (1 + pulse * .15),
      Paint()..color = color.withValues(alpha: .6 + pulse * .25),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      color != oldDelegate.color ||
      compact != oldDelegate.compact;
}
