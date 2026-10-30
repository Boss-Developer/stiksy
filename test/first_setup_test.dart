import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/config/app_routes.dart';
import 'package:stiksy/app/mvvm/view/splash/splash_view.dart';
import 'package:stiksy/app/mvvm/view_model/splash/splash_controller.dart';
import 'package:stiksy/app/services/remote_content.dart';

/// Opens the real splash screen with a fake downloader, so the first-launch
/// flow can be driven without a server.
Future<SplashController> openSplash(
  WidgetTester tester,
  Future<BootstrapStatus> Function(SetupReport) bootstrap, {
  bool needsSetup = true,
}) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = Get.find<SharedPreferences>();
  late SplashController controller;
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(
          name: '/',
          page: () => const SplashView(),
          binding: BindingsBuilder(() {
            controller = Get.put(
              SplashController(
                prefs,
                bootstrap: bootstrap,
                needsSetup: () => needsSetup,
                minimumSetupTime: Duration.zero,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.homeView,
          page: () => const Scaffold(body: Text('HOME')),
        ),
      ],
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put<SharedPreferences>(
      await SharedPreferences.getInstance(),
      permanent: true,
    );
  });
  tearDown(() => Get.reset());

  testWidgets(
    'first launch shows progress, then opens the app when everything is downloaded',
    (tester) async {
      final gate = Completer<void>();
      await openSplash(tester, (report) async {
        report(0.1, 'Checking your connection…');
        await gate.future;
        report(0.6, 'Getting sticker packs… 12 of 40');
        return BootstrapStatus.ready;
      });
      await tester.pump(const Duration(milliseconds: 50));
      // Nothing opens until the download is done.
      expect(find.text('HOME'), findsNothing);
      expect(find.text('Checking your connection…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(Get.find<SharedPreferences>().getBool('stiksy_onboarded'), true);
    },
  );

  testWidgets('shows the download progress as a fraction of the bar', (
    tester,
  ) async {
    final gate = Completer<void>();
    await openSplash(tester, (report) async {
      report(0.5, 'Getting template pictures…');
      await gate.future;
      return BootstrapStatus.ready;
    });
    await tester.pump(const Duration(milliseconds: 50));
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
    gate.complete();
    await tester.pumpAndSettle();
  });

  for (final status in [BootstrapStatus.offline, BootstrapStatus.failed]) {
    testWidgets(
      '${status.name}: opens with the built-in designs instead of an error screen',
      (tester) async {
        await openSplash(tester, (report) async => status);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        expect(find.textContaining('built-in designs'), findsOneWidget);
        final prefs = Get.find<SharedPreferences>();
        // Later launches refresh in the background instead of asking again.
        expect(prefs.getBool(RemoteContent.skipSetupKey), true);
        expect(prefs.getBool('stiksy_onboarded'), true);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'an unexpected error in the download still opens the app, not a crash',
    (tester) async {
      await openSplash(tester, (report) async => throw StateError('boom'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('when no setup is needed the normal short splash is used', (
    tester,
  ) async {
    var called = false;
    await Get.find<SharedPreferences>().setBool('stiksy_onboarded', true);
    await openSplash(tester, (report) async {
      called = true;
      return BootstrapStatus.ready;
    }, needsSetup: false);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text('HOME'), findsOneWidget);
  });
}
