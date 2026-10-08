import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Supported font families.
///
/// [AppFontFamily.inter] is the default. Rubik and Sarabun are pulled from
/// Google Fonts on demand. [AppFontFamily.sfPro] uses the platform system font
/// — which is SF Pro on iOS/macOS and the default sans-serif elsewhere; bundle
/// the SF Pro font files as an asset if you need it on every platform.
enum AppFontFamily { inter, rubik, sarabun, sfPro }

/// Centralized, responsive typography for the LayerX app.
///
/// Never write a raw [TextStyle] inside a view — compose from these tokens so
/// weight, size, and font family stay consistent everywhere. Change
/// [fontFamily] in one place to restyle the entire app.
abstract class AppTextStyles {
  AppTextStyles._();

  static AppFontFamily fontFamily = AppFontFamily.inter;

  static TextStyle _applyFamily(AppFontFamily family, TextStyle style) {
    switch (family) {
      case AppFontFamily.inter:
        return GoogleFonts.inter(textStyle: style);
      case AppFontFamily.rubik:
        return GoogleFonts.rubik(textStyle: style);
      case AppFontFamily.sarabun:
        return GoogleFonts.sarabun(textStyle: style);
      case AppFontFamily.sfPro:
        // Platform system font: SF Pro on Apple platforms, default elsewhere.
        return style;
    }
  }

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return _applyFamily(
      fontFamily,
      TextStyle(
        fontSize: size.sp,
        fontWeight: weight,
        color: color ?? AppColors.textDarkColor,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }

  // Display & headlines
  static TextStyle get displayLarge =>
      _style(size: 32, weight: FontWeight.w700, height: 1.2);
  static TextStyle get headline =>
      _style(size: 24, weight: FontWeight.w700, height: 1.25);
  static TextStyle get title =>
      _style(size: 20, weight: FontWeight.w600, height: 1.3);
  static TextStyle get subtitle => _style(size: 16, weight: FontWeight.w600);

  // Body
  static TextStyle get bodyLarge =>
      _style(size: 16, weight: FontWeight.w400, height: 1.4);
  static TextStyle get bodyMedium =>
      _style(size: 14, weight: FontWeight.w400, height: 1.4);
  static TextStyle get bodySmall => _style(
    size: 12,
    weight: FontWeight.w400,
    color: AppColors.textLightBlack,
  );

  // Utility
  static TextStyle get button =>
      _style(size: 16, weight: FontWeight.w600, color: AppColors.white);
  static TextStyle get label => _style(size: 14, weight: FontWeight.w500);
  static TextStyle get caption => _style(
    size: 11,
    weight: FontWeight.w400,
    color: AppColors.textLightBlack,
  );
}
