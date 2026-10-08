import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../services/haptic_service.dart';

/// A premium, reusable button with a press-scale animation, ripple, optional
/// gradient, leading/trailing icons, a loading state and haptic feedback.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.suffixIcon,
    this.gradient,
    this.color,
    this.textColor,
    this.height,
    this.width,
    this.borderRadius,
    this.isLoading = false,
    this.enableHaptics = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? suffixIcon;
  final Gradient? gradient;
  final Color? color;
  final Color? textColor;
  final double? height;
  final double? width;
  final double? borderRadius;
  final bool isLoading;
  final bool enableHaptics;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _handleTap() {
    if (!_enabled) return;
    if (widget.enableHaptics) HapticService.light();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius ?? 14.r);
    final textColor = widget.textColor ?? AppColors.white;
    final background = widget.gradient == null
        ? (widget.color ?? AppColors.primary)
        : null;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: _enabled ? 1 : 0.6,
        child: Material(
          color: background,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: radius,
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: _enabled ? _handleTap : null,
              onHighlightChanged: _enabled
                  ? (v) => setState(() => _pressed = v)
                  : null,
              child: Container(
                height: widget.height ?? 52.h,
                width: widget.width,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: widget.isLoading
                    ? SizedBox(
                        height: 22.r,
                        width: 22.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: textColor, size: 20.r),
                            SizedBox(width: 8.w),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.button.copyWith(
                                color: textColor,
                              ),
                            ),
                          ),
                          if (widget.suffixIcon != null) ...[
                            SizedBox(width: 8.w),
                            Icon(
                              widget.suffixIcon,
                              color: textColor,
                              size: 20.r,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
