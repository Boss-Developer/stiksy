import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiksy/app/config/app_radius.dart';
import 'package:stiksy/app/config/app_theme.dart';

/// Painted artwork keeps its own tiny radii (sticker checkerboard, crown,
/// shape painter, watermark label). Everything else must use [AppRadius].
const _artwork = {
  'lib/app/custom_widgets/sticker_background.dart',
  'lib/app/custom_widgets/stiksy_crown.dart',
  'lib/app/mvvm/view/editor/sticker_editor_view.dart',
  'lib/app/services/sticker_renderer.dart',
  'lib/app/config/app_radius.dart',
};

void main() {
  test('the scale matches the admin panel', () {
    expect(
      [AppRadius.xs, AppRadius.sm, AppRadius.md, AppRadius.lg],
      [6, 9, 12, 16],
    );
  });

  test('no screen or widget hard-codes a corner radius', () {
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(String.fromCharCode(92), '/');
      if (!path.endsWith('.dart') || _artwork.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(
          r'BorderRadius\.(circular|all|only|vertical)\(|Radius\.circular\(\s*\d|StadiumBorder',
        ).hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use AppRadius (xs/sm/md/lg) instead:\n${offenders.join('\n')}',
    );
  });

  test('the editor file only paints artwork with literal radii', () {
    final hits = File('lib/app/mvvm/view/editor/sticker_editor_view.dart')
        .readAsLinesSync()
        .where(
          (l) => RegExp(
            r'BorderRadius\.(circular|all|only|vertical)\(',
          ).hasMatch(l),
        );
    expect(hits, isEmpty);
  });

  group('theme', () {
    final theme = AppTheme.light;
    RoundedRectangleBorder rounded(ShapeBorder? s) =>
        s! as RoundedRectangleBorder;

    test('dialogs and sheets use the large radius, cards the card radius', () {
      expect(rounded(theme.dialogTheme.shape).borderRadius, AppRadius.lgAll);
      expect(
        rounded(theme.bottomSheetTheme.shape).borderRadius,
        AppRadius.sheet,
      );
      expect(rounded(theme.cardTheme.shape).borderRadius, AppRadius.mdAll);
      expect(rounded(theme.popupMenuTheme.shape).borderRadius, AppRadius.mdAll);
    });

    test('buttons, chips and inputs share the control radius', () {
      expect(
        rounded(theme.filledButtonTheme.style!.shape!.resolve({})).borderRadius,
        AppRadius.smAll,
      );
      expect(
        rounded(
          theme.outlinedButtonTheme.style!.shape!.resolve({}),
        ).borderRadius,
        AppRadius.smAll,
      );
      expect(
        rounded(theme.textButtonTheme.style!.shape!.resolve({})).borderRadius,
        AppRadius.smAll,
      );
      expect(rounded(theme.chipTheme.shape).borderRadius, AppRadius.smAll);
      expect(
        rounded(theme.floatingActionButtonTheme.shape).borderRadius,
        AppRadius.smAll,
      );
      expect(
        (theme.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
        AppRadius.smAll,
      );
    });
  });
}
