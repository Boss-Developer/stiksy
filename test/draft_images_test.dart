import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stiksy/app/mvvm/model/editor_layer.dart';
import 'package:stiksy/app/services/draft_images.dart';

import 'fake_paths.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = installFakePaths());
  tearDown(() => tmp.deleteSync(recursive: true));

  final photo = base64Encode(List.generate(64, (i) => i));
  Map<String, dynamic> design() => {
    'layers': [
      {'id': 'a', 'kind': 'image', 'content': photo},
      {'id': 'b', 'kind': 'text', 'content': 'hello'},
    ],
    'backgroundImage': photo,
    'backgroundMode': 3,
  };

  test('photos move to files and come back unchanged', () async {
    final stored = await DraftImages.externalize(design());
    expect(jsonEncode(stored).contains(photo), isFalse);
    final restored = await DraftImages.inline(stored);
    expect(restored['layers'][0]['content'], photo);
    expect(restored['backgroundImage'], photo);
    expect(restored['layers'][1]['content'], 'hello');
  });

  test('missing files drop the layer and reset the background', () async {
    final stored = await DraftImages.externalize(design());
    await DraftImages.collect([]);
    final restored = await DraftImages.inline(stored);
    expect((restored['layers'] as List).length, 1);
    expect(restored['backgroundImage'], isNull);
    expect(restored['backgroundMode'], 0);
  });

  test('collect keeps only referenced files', () async {
    final stored = await DraftImages.externalize(design());
    await DraftImages.collect([jsonEncode(stored)]);
    final dir = Directory('${tmp.path}/draft_images');
    expect(dir.listSync().length, 1);
    await DraftImages.collect([]);
    expect(dir.listSync(), isEmpty);
  });

  test('corrupt layer JSON falls back to safe defaults', () {
    final layer = EditorLayer.fromJson({});
    expect(layer.kind, 'text');
    expect(layer.content, '');
    expect(layer.id, isNotEmpty);
  });
}
