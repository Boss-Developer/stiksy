import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'secure_session_storage.dart';

class CatalogPack {
  CatalogPack(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get category => data['category'] as String;
  String get version => data['version'].toString();
  int get stickerCount => data['stickerCount'] as int;
  int get downloadBytes => (data['downloadBytes'] as num?)?.toInt() ?? 0;
  String get manifest => data['manifest'] as String;
  String get manifestSha256 => data['manifestSha256'] as String;
  String get cover => data['cover'] as String;

  /// Remote folder name, e.g. `01-chai-ho-jaye`.
  String get folder => manifest.split('/').first;
}

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Loads the sticker catalog from a private Supabase bucket and keeps
/// verified copies in app-private storage.
abstract class CatalogService {
  static final _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static bool _ready = false;
  static SupabaseClient get _client => Supabase.instance.client;
  static StorageFileApi get _bucket =>
      _client.storage.from(SupabaseConfig.bucket);

  /// Starts Supabase and signs in anonymously. Safe to call repeatedly.
  static Future<void> initialize() async {
    if (_ready) return;
    if (!SupabaseConfig.configured) {
      throw CatalogException('Online catalog is not configured.');
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: const SecureSessionStorage(),
        ),
      );
    } catch (_) {
      // Already initialised (hot restart).
    }
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
    _ready = true;
  }

  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/catalog/v1').create(recursive: true);
  }

  static Future<File> _catalogFile() async =>
      File('${(await _root()).path}/catalog.json');

  static String _hex(List<int> bytes) => sha256.convert(bytes).toString();

  static void _checkName(String name) {
    if (!_safeName.hasMatch(name)) {
      throw CatalogException('Catalog contains an unsafe file name.');
    }
  }

  /// Fetches the catalog; falls back to the last cached copy when offline.
  static Future<List<CatalogPack>> loadCatalog() async {
    final cache = await _catalogFile();
    try {
      await initialize();
      final bytes = await _bucket.download(SupabaseConfig.catalogPath);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final packs = _parse(json);
      await cache.writeAsBytes(bytes, flush: true);
      return packs;
    } catch (e) {
      if (await cache.exists()) {
        return _parse(jsonDecode(await cache.readAsString()));
      }
      if (e is CatalogException) rethrow;
      throw CatalogException('Unable to load stickers. Check your connection.');
    }
  }

  static List<CatalogPack> _parse(Map<String, dynamic> json) {
    final packs = (json['packs'] as List)
        .map((p) => CatalogPack(p as Map<String, dynamic>))
        .toList();
    for (final p in packs) {
      _checkName(p.folder);
    }
    return packs;
  }

  static Future<Directory> packDir(CatalogPack pack) async =>
      Directory('${(await _root()).path}/${pack.folder}');

  /// True when the pack is stored locally at the catalog's current version.
  static Future<bool> isDownloaded(CatalogPack pack) async {
    final manifest = File('${(await packDir(pack)).path}/pack.json');
    if (!await manifest.exists()) return false;
    try {
      final local = jsonDecode(await manifest.readAsString());
      return local['version'].toString() == pack.version;
    } catch (_) {
      return false;
    }
  }

  /// Cover image bytes, cached after the first fetch.
  static Future<Uint8List?> cover(CatalogPack pack) async {
    final dir = await packDir(pack);
    final file = File('${dir.path}/cover.webp');
    if (await file.exists()) return file.readAsBytes();
    try {
      await initialize();
      final bytes = await _bucket.download('v1/${pack.cover}');
      await dir.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Downloads a pack, verifies every checksum, then swaps it in atomically.
  static Future<void> download(
    CatalogPack pack, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await initialize();
      final manifestBytes = await _bucket.download('v1/${pack.manifest}');
      if (_hex(manifestBytes) != pack.manifestSha256) {
        throw CatalogException('Pack manifest failed verification.');
      }
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map;
      final stickers = (manifest['stickers'] as List).cast<Map>();
      final root = await _root();
      final temp = Directory('${root.path}/.tmp-${pack.folder}');
      if (await temp.exists()) await temp.delete(recursive: true);
      await temp.create(recursive: true);
      try {
        final files = [
          ...stickers.map((s) => s['file'] as String),
          manifest['tray'] as String,
        ];
        for (var i = 0; i < files.length; i++) {
          final name = files[i];
          _checkName(name);
          final bytes = await _bucket.download('v1/${pack.folder}/$name');
          final entry = stickers.cast<Map?>().firstWhere(
            (s) => s!['file'] == name,
            orElse: () => null,
          );
          if (entry != null &&
              (bytes.length != entry['bytes'] ||
                  _hex(bytes) != entry['sha256'])) {
            throw CatalogException('A sticker failed verification.');
          }
          await File('${temp.path}/$name').writeAsBytes(bytes, flush: true);
          onProgress?.call((i + 1) / files.length);
        }
        final cover = File('${(await packDir(pack)).path}/cover.webp');
        if (await cover.exists()) await cover.copy('${temp.path}/cover.webp');
        // Manifest is written last: its presence marks a complete pack.
        await File('${temp.path}/pack.json').writeAsBytes(manifestBytes);
        final target = await packDir(pack);
        if (await target.exists()) await target.delete(recursive: true);
        await temp.rename(target.path);
      } catch (_) {
        if (await temp.exists()) await temp.delete(recursive: true);
        rethrow;
      }
    } on CatalogException {
      rethrow;
    } catch (_) {
      throw CatalogException('Download failed. Check your connection.');
    }
  }

  /// Local sticker files for a downloaded pack, in manifest order.
  static Future<List<File>> stickerFiles(CatalogPack pack) async {
    final dir = await packDir(pack);
    final manifest = await manifestOf(pack);
    return (manifest['stickers'] as List)
        .map((s) => File('${dir.path}/${s['file']}'))
        .toList();
  }

  static Future<Map<String, dynamic>> manifestOf(CatalogPack pack) async {
    final file = File('${(await packDir(pack)).path}/pack.json');
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  static Future<void> remove(CatalogPack pack) async {
    final dir = await packDir(pack);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
