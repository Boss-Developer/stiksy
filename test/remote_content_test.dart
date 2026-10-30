import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiksy/app/app_widget.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/services/remote_content.dart';
import 'package:stiksy/app/services/template_access.dart';

import 'fake_paths.dart';

Map<String, dynamic> template(
  String id, {
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'title': 'Title $id',
  'category': 'Urdu',
  'text': 'متن',
  'emoji': '✨',
  'color': '#D1FAE5',
  'premium': false,
  ...extra,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    RemoteContent.settings.value = const RemoteSettings();
    templatesNotifier.value = builtInTemplates;
    categoriesNotifier.value = builtInCategories;
  });

  group('settings', () {
    test('an empty or missing section keeps today\'s behaviour', () {
      for (final json in [
        null,
        'x',
        <String, dynamic>{},
        {'features': 5},
      ]) {
        final s = RemoteSettings.fromJson(json);
        expect(s.ads && s.rewardedVideo && s.purchase && s.catalog, isTrue);
        expect(s.premiumUnlockHours, 24);
        expect(s.maxDrafts, 20);
        expect(s.homeTitle, 'A little more you.');
        expect(s.presets, RemoteSettings.defaultPresets);
        expect(s.elements, RemoteSettings.defaultElements);
      }
    });

    test('valid values apply and wrong types are ignored one by one', () {
      final s = RemoteSettings.fromJson({
        'features': {'ads': false, 'purchase': 'yes', 'catalog': false},
        'rules': {'premiumUnlockHours': 48, 'maxDrafts': 'many'},
        'copy': {'homeTitle': 'Salaam', 'homeSubtitle': 7},
        'app': {'minVersion': '2.0.0', 'maintenanceMessage': 'Back soon'},
      });
      expect(s.ads, isFalse);
      expect(s.purchase, isTrue, reason: 'bad type keeps the default');
      expect(s.catalog, isFalse);
      expect(s.premiumUnlockHours, 48);
      expect(s.maxDrafts, 20);
      expect(s.homeTitle, 'Salaam');
      expect(
        s.homeSubtitle,
        'Turn everyday moments into stickers worth sending.',
      );
      expect(s.minVersion, '2.0.0');
      expect(s.maintenanceMessage, 'Back soon');
    });

    test('numbers outside the safe range are ignored', () {
      final s = RemoteSettings.fromJson({
        'rules': {'premiumUnlockHours': 0, 'maxDrafts': 100000},
      });
      expect(s.premiumUnlockHours, 24);
      expect(s.maxDrafts, 20);
    });

    test('text styles and emoji sets are read, malformed ones dropped', () {
      final s = RemoteSettings.fromJson({
        'presets': [
          {
            'name': 'Mint',
            'color': '#00FF88',
            'outline': true,
            'outlineWidth': 4,
            'shadow': false,
            'shadowBlur': 2,
          },
          {'name': 'Bad colour', 'color': 'green'},
          {'color': '#000000'},
          'junk',
        ],
        'elements': [
          {
            'category': 'Food',
            'emojis': ['🍕', '', '🍔'],
          },
          {'category': 5, 'emojis': []},
        ],
        'upgrade': {
          'benefits': ['One', '  ', 'Two'],
        },
      });
      expect(s.presets, hasLength(1));
      expect(s.presets.single.name, 'Mint');
      expect(s.presets.single.color, 0xFF00FF88);
      expect(s.presets.single.outlineWidth, 4);
      expect(s.elements.single.category, 'Food');
      expect(s.elements.single.emojis, ['🍕', '🍔']);
      expect(s.upgradeBenefits, ['One', 'Two']);
    });

    test('a list that is entirely bad falls back to the defaults', () {
      final s = RemoteSettings.fromJson({
        'presets': ['x'],
        'elements': [],
      });
      expect(s.presets, RemoteSettings.defaultPresets);
      expect(s.elements, RemoteSettings.defaultElements);
    });
  });

  test('versions compare numerically', () {
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    expect(compareVersions('junk', '0.0.0'), 0);
  });

  group('templates', () {
    final now = DateTime.utc(2026, 3, 15);

    test('reads fields, colour and premium', () async {
      final list = await RemoteContent.parseTemplates([
        template('a', extra: {'premium': true, 'color': '#FF0000'}),
      ], now);
      expect(list.single.id, 'a');
      expect(list.single.premium, isTrue);
      expect(list.single.color, const Color(0xFFFF0000));
      expect(list.single.asset, isNull);
    });

    test('skips malformed entries without losing the good ones', () async {
      final list = await RemoteContent.parseTemplates([
        template('ok'),
        {'id': 'no-title', 'category': 'Urdu', 'color': '#FFFFFF'},
        template('bad-colour', extra: {'color': 'red'}),
        'junk',
        template('also-ok'),
      ], now);
      expect(list.map((t) => t.id), ['ok', 'also-ok']);
    });

    test('honours the start and end dates', () async {
      final list = await RemoteContent.parseTemplates([
        template(
          'live',
          extra: {
            'startsAt': '2026-03-01T00:00:00Z',
            'endsAt': '2026-04-01T00:00:00Z',
          },
        ),
        template('later', extra: {'startsAt': '2026-04-01T00:00:00Z'}),
        template('over', extra: {'endsAt': '2026-03-15T00:00:00Z'}),
      ], now);
      expect(list.map((t) => t.id), ['live']);
    });

    test(
      'keeps a built-in image when its hash matches the published one',
      () async {
        final bundled = File('assets/stickers/chai.webp').readAsBytesSync();
        final list = await RemoteContent.parseTemplates([
          template(
            'funny1',
            extra: {
              'art': {
                'path': 'templates/funny1.webp',
                'sha256': sha256.convert(bundled).toString(),
                'bytes': bundled.length,
              },
            },
          ),
        ], now);
        expect(list.single.asset, 'assets/stickers/chai.webp');
      },
    );

    test(
      'shows the bundled image until a changed one has downloaded',
      () async {
        final list = await RemoteContent.parseTemplates([
          template(
            'funny1',
            extra: {
              'art': {
                'path': 'templates/funny1.webp',
                'sha256': 'f' * 64,
                'bytes': 10,
              },
            },
          ),
          template(
            'brandnew',
            extra: {
              'art': {
                'path': 'templates/brandnew.webp',
                'sha256': 'e' * 64,
                'bytes': 10,
              },
            },
          ),
        ], now);
        expect(list.first.asset, 'assets/stickers/chai.webp');
        expect(list.last.asset, isNull);
      },
    );
  });

  group('applying a release', () {
    final release = {
      'schemaVersion': 1,
      'version': 3,
      'settings': {
        'features': {'ads': false},
        'copy': {'homeTitle': 'Eid Mubarak'},
      },
      'categories': [
        {'id': 'eid', 'name': 'Eid'},
        {'id': 'later', 'name': 'Later', 'startsAt': '2999-01-01T00:00:00Z'},
        {'id': 'urdu', 'name': 'Urdu'},
      ],
      'templates': [template('t1'), template('t2')],
    };

    test('replaces templates, categories and settings and notifies', () async {
      final before = RemoteContent.revision.value;
      await RemoteContent.apply(release, now: DateTime.utc(2026, 3, 15));
      expect(stickerTemplates.map((t) => t.id), ['t1', 't2']);
      expect(templateCategories, ['All', 'Eid', 'Urdu']);
      expect(RemoteContent.settings.value.ads, isFalse);
      expect(RemoteContent.settings.value.homeTitle, 'Eid Mubarak');
      expect(RemoteContent.revision.value, before + 1);
    });

    test(
      'the release number only moves when a release really changes',
      () async {
        await RemoteContent.apply({
          ...release,
          'version': 7,
        }, now: DateTime.utc(2026, 3, 15));
        expect(RemoteContent.release, 7);
        // The same release downloaded again is not news.
        await RemoteContent.apply({
          ...release,
          'version': 7,
        }, now: DateTime.utc(2026, 3, 15));
        expect(RemoteContent.release, 7);
        // A manifest without a number keeps what we had.
        await RemoteContent.apply(
          {...release}..remove('version'),
          now: DateTime.utc(2026, 3, 15),
        );
        expect(RemoteContent.release, 7);
      },
    );

    test('an empty template list never empties the app', () async {
      await RemoteContent.apply({
        'schemaVersion': 1,
        'templates': [],
        'categories': [],
      }, now: DateTime.utc(2026));
      expect(stickerTemplates, builtInTemplates);
      expect(templateCategories, builtInCategories);
    });

    test('garbage changes nothing', () async {
      await RemoteContent.apply('not a release', now: DateTime.utc(2026));
      await RemoteContent.apply(null, now: DateTime.utc(2026));
      expect(stickerTemplates, builtInTemplates);
      expect(RemoteContent.settings.value.ads, isTrue);
    });

    test('survives a release that went through JSON text', () async {
      await RemoteContent.apply(
        jsonDecode(jsonEncode(release)),
        now: DateTime.utc(2026, 3, 15),
      );
      expect(stickerTemplates, hasLength(2));
    });
  });

  group('switches', () {
    setUp(() async {
      installFakePaths();
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({'stiksy_onboarded': true});
      Get.put<SharedPreferences>(
        await SharedPreferences.getInstance(),
        permanent: true,
      );
    });
    tearDown(() => Get.reset());

    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const LayerXApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('purchase and catalog switches hide their entry points', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.byTooltip('Remove ads'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      RemoteContent.settings.value = const RemoteSettings(
        purchase: false,
        catalog: false,
      );
      RemoteContent.revision.value++;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove ads'), findsNothing);
      expect(find.text('Catalog'), findsNothing);
      // The rest of the bar is untouched.
      expect(find.text('My Packs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('published home texts replace the built-in ones live', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.text('A little more you.'), findsOneWidget);
      RemoteContent.settings.value = const RemoteSettings(
        homeTitle: 'Eid Mubarak!',
      );
      RemoteContent.revision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Eid Mubarak!'), findsOneWidget);
      expect(find.text('A little more you.'), findsNothing);
    });

    testWidgets('new templates and categories appear on the Templates tab', (
      tester,
    ) async {
      await openHome(tester);
      await tester.tap(find.text('Templates').last);
      await tester.pumpAndSettle();
      await RemoteContent.apply({
        'schemaVersion': 1,
        'categories': [
          {'id': 'eid', 'name': 'Eid Special'},
        ],
        'templates': [
          template(
            'eid-1',
            extra: {'title': 'Eid Mubarak Card', 'category': 'Eid Special'},
          ),
        ],
      }, now: DateTime.utc(2026));
      await tester.pumpAndSettle();
      // The chips sit below the hero and search box; scroll them into view.
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Eid Special'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(ChoiceChip, 'Eid Special'), findsOneWidget);
      expect(find.text('1 templates'), findsOneWidget);
    });

    testWidgets('with rewarded video off, premium templates need no video', (
      tester,
    ) async {
      final premium = builtInTemplates.firstWhere((t) => t.premium);
      RemoteContent.settings.value = const RemoteSettings(rewardedVideo: false);
      bool? allowed;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  allowed = await TemplateAccess.allow(context, premium),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(allowed, isTrue);
      expect(find.text('Export this premium design'), findsNothing);
    });
  });
}
