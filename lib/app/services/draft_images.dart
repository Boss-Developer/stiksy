import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

abstract class DraftImages {
  static const _prefix = 'file:';

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/draft_images').create(recursive: true);
  }

  static bool _isImageLayer(dynamic l) => l is Map && l['kind'] == 'image';

  static Set<String> references(Map<String, dynamic> snapshot) => {
    for (final l in (snapshot['layers'] as List? ?? []))
      if (_isImageLayer(l) && '${l['content']}'.startsWith(_prefix))
        '${l['content']}'.substring(_prefix.length),
    if ('${snapshot['backgroundImage']}'.startsWith(_prefix))
      '${snapshot['backgroundImage']}'.substring(_prefix.length),
  };

  static Future<String> _store(Directory dir, String base64Data) async {
    if (base64Data.startsWith(_prefix)) return base64Data;
    final bytes = base64Decode(base64Data);
    final name = '${sha256.convert(bytes)}.img';
    final file = File('${dir.path}/$name');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return '$_prefix$name';
  }

  static Future<Map<String, dynamic>> externalize(
    Map<String, dynamic> snapshot,
  ) async {
    final dir = await _dir();
    final out = Map<String, dynamic>.from(snapshot);
    out['layers'] = [
      for (final l in (snapshot['layers'] as List? ?? []))
        _isImageLayer(l)
            ? {...l as Map, 'content': await _store(dir, '${l['content']}')}
            : l,
    ];
    final bg = snapshot['backgroundImage'];
    if (bg is String && bg.isNotEmpty) {
      out['backgroundImage'] = await _store(dir, bg);
    }
    return out;
  }

  static Future<Map<String, dynamic>> inline(
    Map<String, dynamic> design,
  ) async {
    final dir = await _dir();
    Future<String?> load(String ref) async {
      if (!ref.startsWith(_prefix)) return ref;
      final name = ref.substring(_prefix.length);
      if (!RegExp(r'^[a-f0-9]{64}\.img$').hasMatch(name)) return null;
      final file = File('${dir.path}/$name');
      return await file.exists()
          ? base64Encode(await file.readAsBytes())
          : null;
    }

    final out = Map<String, dynamic>.from(design);
    final layers = <dynamic>[];
    for (final l in (design['layers'] as List? ?? [])) {
      if (!_isImageLayer(l)) {
        layers.add(l);
        continue;
      }
      final data = await load('${l['content']}');
      if (data != null) layers.add({...l as Map, 'content': data});
    }
    if (design.containsKey('layers')) out['layers'] = layers;
    final bg = design['backgroundImage'];
    if (bg is String && bg.isNotEmpty) {
      out['backgroundImage'] = await load(bg);
      if (out['backgroundImage'] == null) out['backgroundMode'] = 0;
    }
    return out;
  }

  static Future<void> collect(Iterable<String> draftsJson) async {
    final keep = <String>{};
    for (final raw in draftsJson) {
      try {
        keep.addAll(references(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    final dir = await _dir();
    await for (final f in dir.list()) {
      if (f is File && !keep.contains(f.uri.pathSegments.last)) {
        await f.delete();
      }
    }
  }
}
