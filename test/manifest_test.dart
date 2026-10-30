import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stiksy/app/mvvm/model/sticker_template.dart';
import 'package:stiksy/app/services/catalog_service.dart';
import 'package:stiksy/app/services/remote_content.dart';

import 'fake_paths.dart';

Map<String, dynamic> pack(String id, String folder) => {
  'id': id,
  'title': 'Pack $id',
  'category': 'Chai',
  'version': '1',
  'stickerCount': 10,
  'manifest': '$folder/pack.json',
  'manifestSha256': 'a' * 64,
  'cover': '$folder/cover.webp',
  'tray': '$folder/tray.png',
  'downloadBytes': 1000,
};

Map<String, dynamic> manifest({List<Map<String, dynamic>>? packs}) => {
  'schemaVersion': 2,
  'version': 3,
  'settings': {
    'copy': {'homeTitle': 'Eid Mubarak'},
  },
  'categories': [
    {'id': 'urdu', 'name': 'Urdu'},
  ],
  'templates': [
    {
      'id': 't1',
      'title': 'T1',
      'category': 'Urdu',
      'text': 'x',
      'emoji': '✨',
      'color': '#D1FAE5',
      'premium': false,
    },
  ],
  'catalog': {
    'packs': packs ?? [pack('p1', '01-chai'), pack('p2', '02-gup')],
  },
};

void main() {
  late Directory support;
  setUp(() {
    support = installFakePaths();
    RemoteContent.reset();
  });
  tearDown(() {
    RemoteContent.reset();
    RemoteContent.settings.value = const RemoteSettings();
    templatesNotifier.value = builtInTemplates;
    categoriesNotifier.value = builtInCategories;
  });

  File cacheFile(String name) {
    final dir = Directory('${support.path}/content')
      ..createSync(recursive: true);
    return File('${dir.path}/$name');
  }

  group('one manifest carries everything', () {
    test('is recognised by schema 2 plus a catalog section', () {
      expect(RemoteContent.isManifest(manifest()), isTrue);
      expect(
        RemoteContent.isManifest({'schemaVersion': 1, 'templates': []}),
        isFalse,
      );
      expect(RemoteContent.isManifest({'schemaVersion': 2}), isFalse);
      expect(RemoteContent.isManifest('x'), isFalse);
      expect(RemoteContent.isManifest(null), isFalse);
    });

    test(
      'applying it updates templates, settings and the pack list together',
      () async {
        await RemoteContent.apply(manifest(), now: DateTime.utc(2026));
        expect(stickerTemplates.map((t) => t.id), ['t1']);
        expect(RemoteContent.settings.value.homeTitle, 'Eid Mubarak');
        final packs = CatalogService.parsePacks(RemoteContent.catalogJson);
        expect(packs.map((p) => p.id), ['p1', 'p2']);
      },
    );

    test(
      'older published files (content.json + catalog.json) are merged into the same shape',
      () {
        final merged = RemoteContent.mergeLegacy(
          {'schemaVersion': 1, 'version': 1, 'templates': [], 'settings': {}},
          {
            'packs': [pack('p1', '01-chai')],
          },
        );
        expect(RemoteContent.isManifest(merged), isTrue);
        expect(merged['version'], 1);
        expect(
          CatalogService.parsePacks(merged['catalog'] as Map).single.id,
          'p1',
        );
      },
    );
  });

  group('the saved copy on the device', () {
    test(
      'loading it makes the app fully ready before any network request',
      () async {
        cacheFile('manifest.json').writeAsStringSync(jsonEncode(manifest()));
        await RemoteContent.loadCached();
        expect(RemoteContent.hasCache, isTrue);
        expect(stickerTemplates.single.id, 't1');
        expect(
          CatalogService.parsePacks(RemoteContent.catalogJson),
          hasLength(2),
        );
      },
    );

    test(
      'with nothing saved the built-in content stays and setup is still needed',
      () async {
        await RemoteContent.loadCached();
        expect(RemoteContent.hasCache, isFalse);
        expect(stickerTemplates, builtInTemplates);
        expect(RemoteContent.catalogJson, isNull);
      },
    );

    test(
      'a copy saved by an older build still shows templates but does not count as set up',
      () async {
        cacheFile('content.json').writeAsStringSync(
          jsonEncode({
            'schemaVersion': 1,
            'templates': manifest()['templates'],
            'settings': {},
            'categories': [],
          }),
        );
        await RemoteContent.loadCached();
        expect(stickerTemplates.single.id, 't1');
        expect(RemoteContent.hasCache, isFalse);
      },
    );

    test('a corrupt copy is ignored instead of crashing', () async {
      cacheFile('manifest.json').writeAsStringSync('{not json');
      await RemoteContent.loadCached();
      expect(RemoteContent.hasCache, isFalse);
      expect(stickerTemplates, builtInTemplates);
    });
  });

  group('the pack list', () {
    test('is empty when the manifest has no catalog', () {
      expect(CatalogService.parsePacks(null), isEmpty);
      expect(CatalogService.parsePacks({}), isEmpty);
      expect(CatalogService.parsePacks({'packs': 'x'}), isEmpty);
    });

    test(
      'rejects a pack whose folder name could escape the storage folder',
      () {
        expect(
          () => CatalogService.parsePacks({
            'packs': [pack('p', '../evil')],
          }),
          throwsA(isA<CatalogException>()),
        );
      },
    );

    test(
      'loading the catalog without a server configured explains why',
      () async {
        await expectLater(
          CatalogService.loadCatalog(),
          throwsA(
            isA<CatalogException>().having(
              (e) => e.message,
              'message',
              contains('not configured'),
            ),
          ),
        );
      },
    );

    test(
      'there is nothing to prefetch, and nothing breaks, for an empty list',
      () async {
        var calls = 0;
        await CatalogService.prefetchCovers(
          const [],
          onProgress: (_, _) => calls++,
        );
        expect(calls, 0);
      },
    );
  });
}
