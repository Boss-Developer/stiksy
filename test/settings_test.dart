import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/view/settings/settings_view.dart';
import 'package:stiksy/app/services/remote_content.dart';

import 'fake_paths.dart';

/// File and plugin calls finish on the real clock, not the test's fake one.
Future<void> settle(WidgetTester tester) async {
  // Every file or plugin hop needs a real tick and then a pump to continue.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const GetMaterialApp(home: SettingsView()));
  await settle(tester);
}

void main() {
  late Directory support;

  setUp(() async {
    support = installFakePaths();
    Get.testMode = true;
    PackageInfo.setMockInitialValues(
      appName: 'Stiksy',
      packageName: 'com.sfdevelopers.stiksy',
      version: '2.3.4',
      buildNumber: '9',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({
      'stiksy_drafts': ['{"template":"a"}', '{"template":"b"}'],
    });
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
    RemoteContent.reset();
  });
  tearDown(() => Get.reset());

  testWidgets('shows the real version, saved designs and the main sections', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Version 2.3.4'), findsOneWidget);
    expect(find.text('2 on this device'), findsOneWidget);
    expect(find.text('How to add stickers to WhatsApp'), findsOneWidget);
    expect(find.text('Rate Stiksy'), findsOneWidget);
    expect(find.text('Default text style'), findsNothing);
    expect(find.text('Open-source licenses'), findsNothing);
    // Support and privacy rows appear only once they are configured.
    expect(find.text('Contact support'), findsNothing);
    expect(find.text('Privacy policy'), findsNothing);
  });

  testWidgets('deleting saved designs asks first, then clears them', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Cancelling keeps everything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      Get.find<SharedPreferences>().getStringList('stiksy_drafts'),
      hasLength(2),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(
      Get.find<SharedPreferences>().getStringList('stiksy_drafts'),
      isEmpty,
    );
    expect(find.text('None yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('downloaded packs show their size and can be cleared', (
    tester,
  ) async {
    final pack = Directory('${support.path}/catalog/v1/demo')
      ..createSync(recursive: true);
    File('${pack.path}/01.webp').writeAsBytesSync(List.filled(2048, 1));
    await open(tester);
    expect(find.text('2 KB'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await settle(tester);
    expect(find.text('0 B'), findsOneWidget);
    expect(pack.existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
