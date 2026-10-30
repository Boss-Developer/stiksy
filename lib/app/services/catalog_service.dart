import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'remote_content.dart';
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

  String get folder => manifest.split('/').first;
}

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CatalogService {
  /// Catalog packs copied into the device's pack store: catalog id →
  /// {local: pack id, version}.
  static const linksKey = 'stiksy_catalog_links';

  /// Local packs that mirror a catalog pack. They are rebuilt whenever the
  /// catalog pack changes, so a user's own stickers must never go into them.
  static Set<String> linkedLocalPackIds(SharedPreferences prefs) {
    try {
      final links = jsonDecode(prefs.getString(linksKey) ?? '{}') as Map;
      return {
        for (final link in links.values)
          if (link is Map && link['local'] is String) link['local'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  static final _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static SupabaseClient get _client => Supabase.instance.client;
  static StorageFileApi get _bucket =>
      _client.storage.from(SupabaseConfig.bucket);

  static Future<void>? _init;

  static Future<void> initialize() {
    if (!SupabaseConfig.configured) {
      return Future.error(
        CatalogException('Online catalog is not configured.'),
      );
    }
    return _init ??= _start().catchError((Object e) {
      _init = null;
      throw e;
    });
  }

  static Future<void> _start() async {
    try {
      // Reading the client throws if Supabase is not initialised yet. Don't
      // rely on `Supabase.instance` alone: its own check is an assert, which
      // release builds remove.
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: const SecureSessionStorage(),
        ),
      );
    }
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously().timeout(RemoteContent.timeout);
    }
  }

  static Future<Uint8List> downloadPublished(String relativePath) async {
    await initialize();
    return _bucket.download('v1/$relativePath').timeout(RemoteContent.timeout);
  }

  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/catalog/v1').create(recursive: true);
  }

  static String _hex(List<int> bytes) => sha256.convert(bytes).toString();

  static void _checkName(String name) {
    if (!_safeName.hasMatch(name)) {
      throw CatalogException('Catalog contains an unsafe file name.');
    }
  }

  /// The packs already on the device, available instantly (no await), or null
  /// when nothing has been downloaded yet.
  static List<CatalogPack>? cachedPacks() {
    final json = RemoteContent.catalogJson;
    return json == null ? null : parsePacks(json);
  }

  static Future<List<CatalogPack>> loadCatalog({bool force = false}) async {
    if (!SupabaseConfig.configured) {
      throw CatalogException('Online catalog is not configured.');
    }
    // Already downloaded at setup: show it now and check for news behind the
    // scenes. Only an explicit pull-to-refresh waits for the network.
    if (!force && RemoteContent.catalogJson != null) {
      unawaited(RemoteContent.refresh());
      return parsePacks(RemoteContent.catalogJson);
    }
    final fresh = await RemoteContent.refresh(force: force);
    final json = RemoteContent.catalogJson;
    if (json == null) {
      throw CatalogException(
        fresh
            ? 'No sticker packs are published yet.'
            : 'Unable to load stickers. Check your connection.',
      );
    }
    return parsePacks(json);
  }

  static List<CatalogPack> parsePacks(Map? catalog) {
    final raw = catalog?['packs'];
    if (raw is! List) return const [];
    final packs = [for (final p in raw) CatalogPack(p as Map<String, dynamic>)];
    for (final p in packs) {
      _checkName(p.folder);
    }
    return packs;
  }

  static Future<void> prefetchCovers(
    List<CatalogPack> packs, {
    void Function(int done, int total)? onProgress,
  }) async {
    var done = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < packs.length) {
        final pack = packs[next++];
        await cover(pack);
        onProgress?.call(++done, packs.length);
      }
    }

    await Future.wait(List.generate(6, (_) => worker()));
  }

  static Future<Directory> packDir(CatalogPack pack) async =>
      Directory('${(await _root()).path}/${pack.folder}');

  /// Disk space used by downloaded sticker packs and their covers.
  static Future<int> downloadedBytes() async {
    var total = 0;
    final root = await _root();
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Deletes downloaded packs and covers. Packs already added to My Packs are
  /// separate copies and stay; the catalog just downloads again when needed.
  static Future<void> clearDownloads() async {
    final root = await _root();
    await root.delete(recursive: true);
    _covers.clear();
  }

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

  static final _covers = <String, Uint8List>{};

  /// Reads every already-downloaded cover into memory, so the Catalog tab
  /// paints them on its first frame instead of showing placeholders.
  static Future<void> warmCovers() async {
    try {
      for (final pack in cachedPacks() ?? const <CatalogPack>[]) {
        final key = '${pack.id}@${pack.version}';
        if (_covers.containsKey(key)) continue;
        final file = File('${(await packDir(pack)).path}/cover.webp');
        if (await file.exists()) _covers[key] = await file.readAsBytes();
      }
    } catch (_) {
      // A cover that can't be read simply loads the normal way later.
    }
  }

  /// A cover already read this session, so revisiting the tab paints at once.
  static Uint8List? coverInMemory(CatalogPack pack) =>
      _covers['${pack.id}@${pack.version}'];

  static Future<Uint8List?> cover(CatalogPack pack) async {
    final key = '${pack.id}@${pack.version}';
    final bytes = await _cover(pack);
    if (bytes != null) _covers[key] = bytes;
    return bytes;
  }

  static Future<Uint8List?> _cover(CatalogPack pack) async {
    final dir = await packDir(pack);
    final file = File('${dir.path}/cover.webp');
    if (await file.exists()) return file.readAsBytes();
    try {
      await initialize();
      final bytes = await _bucket
          .download('v1/${pack.cover}')
          .timeout(RemoteContent.timeout);
      await dir.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> download(
    CatalogPack pack, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await initialize();
      final manifestBytes = await _bucket
          .download('v1/${pack.manifest}')
          .timeout(RemoteContent.timeout);
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
          final bytes = await _bucket
              .download('v1/${pack.folder}/$name')
              .timeout(RemoteContent.timeout);
          final isTray = name == manifest['tray'];
          final entry = stickers.cast<Map?>().firstWhere(
            (s) => s!['file'] == name,
            orElse: () => null,
          );
          final expected = isTray ? manifest['traySha256'] : entry?['sha256'];
          // Older manifests carry no tray checksum; stickers always have one.
          if (expected == null && !isTray) {
            throw CatalogException('A sticker failed verification.');
          }
          if (expected != null &&
              (_hex(bytes) != expected ||
                  (entry != null && bytes.length != entry['bytes']))) {
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
