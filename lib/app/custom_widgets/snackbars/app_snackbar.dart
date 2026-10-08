import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';

enum AlertStatus { success, warning, error }

class PremiumSnackbar {
  PremiumSnackbar._();

  static const _defaultDuration = Duration(seconds: 3);

  /// Public helpers
  static void success(List<String> messages) =>
      _show(messages, AlertStatus.success);

  static void warning(List<String> messages) =>
      _show(messages, AlertStatus.warning);

  static void error(List<String> messages) =>
      _show(messages, AlertStatus.error);

  static void _show(List<String> messages, AlertStatus status) {
    final cfg = _config(status);

    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    final lines = _normalizeMessages(messages);

    Get.snackbar(
      '',
      '',
      snackPosition: SnackPosition.TOP,
      snackStyle: SnackStyle.FLOATING,
      backgroundColor: Colors.white,
      borderRadius: 12,
      margin: EdgeInsets.fromLTRB(50, 60, 50, 0),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      duration: _defaultDuration,
      isDismissible: true,
      // barBlur: 16,
      dismissDirection: DismissDirection.horizontal,
      shouldIconPulse: false,
      titleText: const SizedBox.shrink(),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      messageText: Row(
        crossAxisAlignment: lines.length > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          // Icon bubble (minimal)
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: cfg.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: cfg.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          // Text content (supports List<String>)
          Expanded(
            child: _MessageBlock(lines: lines, textColor: cfg.textColor),
          ),
        ],
      ),
    );
  }

  static List<String> _normalizeMessages(List<String> messages) {
    final cleaned = messages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) return ['Something went wrong'];

    // Keep it minimal: show max 3 lines.
    if (cleaned.length <= 3) return cleaned;

    // If more than 3, show first 2 and summary.
    final remaining = cleaned.length - 2;
    return [cleaned[0], cleaned[1], '+$remaining more'];
  }

  static _SnackConfig _config(AlertStatus status) {
    switch (status) {
      case AlertStatus.success:
        return const _SnackConfig(
          icon: Icons.check,
          iconBgColor: AppColors.primary,
          iconColor: Colors.white,
          textColor: Colors.black,
        );
      case AlertStatus.warning:
        return const _SnackConfig(
          icon: CupertinoIcons.info,
          iconBgColor: Color(0xffe8a52e),
          iconColor: Colors.white,
          textColor: Colors.black,
        );
      case AlertStatus.error:
        return const _SnackConfig(
          icon: Icons.close,
          iconBgColor: Color(0xffcc1200),
          iconColor: Colors.white,
          textColor: Colors.black,
        );
    }
  }
}

class _SnackConfig {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color textColor;

  const _SnackConfig({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.textColor,
  });
}

class _MessageBlock extends StatelessWidget {
  final List<String> lines;
  final Color textColor;

  const _MessageBlock({required this.lines, required this.textColor});

  @override
  Widget build(BuildContext context) {
    // Single line (most common) → one Text
    if (lines.length == 1) {
      return Text(
        lines.first,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      );
    }

    // Multiple lines → small, minimal bullet-ish spacing (no scroll)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) {
        final isLast = i == lines.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 3),
          child: Text(
            lines[i],
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    );
  }
}

/// Extensions
extension QuickSnackbar on List<String> {
  void showSuccess() => PremiumSnackbar.success(this);
  void showWarning() => PremiumSnackbar.warning(this);
  void showError() => PremiumSnackbar.error(this);
}

extension QuickStringSnackbar on String {
  void showSuccess() => PremiumSnackbar.success([this]);
  void showWarning() => PremiumSnackbar.warning([this]);
  void showError() => PremiumSnackbar.error([this]);
}

extension InformationalToast on String {
  void showInfo() => PremiumSnackbar.warning([this]);
}
