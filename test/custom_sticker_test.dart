import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/mvvm/view/create/custom_sticker_view.dart';
import 'package:stiksy/app/mvvm/view/editor/sticker_editor_view.dart';
import 'package:stiksy/app/custom_widgets/snackbars/app_snackbar.dart';

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put(await SharedPreferences.getInstance(), permanent: true);
  });
  tearDown(() => Get.reset());
  testWidgets(
    'custom emoji keeps a complete family sequence and begins with one layer',
    (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: CustomStickerView()));
      await tester.tap(find.text('From any emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '👨‍👩‍👧‍👦');
      await tester.tap(find.text('Use emoji'));
      await tester.pumpAndSettle();
      expect(find.byType(StickerEditorView), findsOneWidget);
      expect(find.text('👨‍👩‍👧‍👦'), findsOneWidget);
      expect(find.text('1 layers'), findsOneWidget);
      expect(find.text('Your words'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets('blank custom canvas contains no template layers', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: CustomStickerView()));
    await tester.ensureVisible(find.text('Start with a blank canvas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start with a blank canvas'));
    await tester.pumpAndSettle();
    expect(find.text('0 layers'), findsOneWidget);
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Hifz toast is a white floating card with a colored icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => 'Sticker saved'.showSuccess(),
              child: const Text('Notify'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Notify'));
    await tester.pumpAndSettle();
    expect(find.text('Sticker saved'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(Get.isSnackbarOpen, true);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Sticker saved'), findsNothing);
  });
}
