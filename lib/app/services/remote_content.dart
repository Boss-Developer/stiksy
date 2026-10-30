import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../config/supabase_config.dart';
import '../mvvm/model/sticker_template.dart';
import 'catalog_service.dart';

class TextPreset {
  const TextPreset(
    this.name,
    this.color,
    this.outline,
    this.outlineWidth,
    this.shadow,
    this.shadowBlur,
  );
  final String name;
  final int color;
  final bool outline, shadow;
  final double outlineWidth, shadowBlur;
}

class ElementSet {
  const ElementSet(this.category, this.emojis);
  final String category;
  final List<String> emojis;
}

class RemoteSettings {
  const RemoteSettings({
    this.ads = true,
    this.rewardedVideo = true,
    this.purchase = true,
    this.catalog = true,
    this.minVersion = '1.0.0',
    this.updateMessage = 'A new version of Stiksy is available.',
    this.maintenanceMessage = '',
    this.storeUrl = '',
    this.premiumUnlockHours = 24,
    this.freeCleanStickers = 3,
    this.maxDrafts = 20,
    this.homeTitle = 'A little more you.',
    this.homeSubtitle = 'Turn everyday moments into stickers worth sending.',
    this.creatorTitle = 'Create a sticker',
    this.creatorSubtitle = 'Your photo. Your words.\nYour kind of fun.',
    this.catalogTitle = 'Pakistani Sticker Packs',
    this.catalogSubtitle =
        'A little chai, a little drama, a lot of expression.',
    this.splashTagline = 'Type Anything\nMake it a Sticker',
    this.aboutText =
        'Create Pakistani-inspired stickers offline. Your favorites and designs stay on this device.',
    this.privacyUrl = '',
    this.supportEmail = '',
    this.upgradeTitle = 'Remove ads & watermark',
    this.upgradeSubtitle = 'One payment. Yours forever. No subscription.',
    this.upgradeBenefits = const [
      'No ads anywhere in the app',
      'No Stiksy watermark on your stickers',
      'Premium templates open, no videos',
      'Helps us keep making new packs',
    ],
    this.productId = '',
    this.presets = defaultPresets,
    this.elements = defaultElements,
  });

  final bool ads, rewardedVideo, purchase, catalog;
  final String minVersion, updateMessage, maintenanceMessage, storeUrl;

  // freeCleanStickers: how many stickers a new user gets without the
  // watermark before any video is asked for.
  final int premiumUnlockHours, freeCleanStickers, maxDrafts;
  final String homeTitle, homeSubtitle, creatorTitle, creatorSubtitle;
  final String catalogTitle, catalogSubtitle, splashTagline, aboutText;
  final String privacyUrl, supportEmail;
  final String upgradeTitle, upgradeSubtitle, productId;
  final List<String> upgradeBenefits;
  final List<TextPreset> presets;
  final List<ElementSet> elements;

  static const defaultPresets = [
    TextPreset('Classic', 0xff302317, true, 5, false, 5),
    TextPreset('Bold red', 0xffef4444, true, 7, true, 4),
    TextPreset('Fresh', 0xff059669, true, 6, false, 5),
    TextPreset('Ocean', 0xff0ea5e9, true, 6, true, 6),
    TextPreset('Sunny', 0xfff59e0b, true, 7, true, 3),
    TextPreset('Pink', 0xfff472b6, true, 6, true, 5),
    TextPreset('Ink', 0xff000000, true, 8, false, 5),
    TextPreset('Clean', 0xffffffff, false, 5, true, 8),
  ];

  static const defaultElements = [
    ElementSet('Emojis', ['☕', '💚', '❤️', '😎', '😂', '👑', '💐', '⭐', '🎉']),
    ElementSet('Cricket', ['🏏', '🏆', '⚾']),
    ElementSet('Flags', ['🇵🇰', '🌙']),
  ];

  factory RemoteSettings.fromJson(Object? json) {
    const d = RemoteSettings();
    if (json is! Map) return d;
    Map section(String key) => json[key] is Map ? json[key] as Map : const {};
    bool flag(Map m, String k, bool fallback) =>
        m[k] is bool ? m[k] as bool : fallback;
    String text(Map m, String k, String fallback) =>
        m[k] is String ? m[k] as String : fallback;
    int count(Map m, String k, int fallback, int min, int max) {
      final v = m[k];
      return v is num && v >= min && v <= max ? v.toInt() : fallback;
    }

    final features = section('features');
    final app = section('app');
    final rules = section('rules');
    final copy = section('copy');
    final upgrade = section('upgrade');

    final benefits = upgrade['benefits'];
    final presets = _presets(json['presets']);
    final elements = _elements(json['elements']);
    return RemoteSettings(
      ads: flag(features, 'ads', d.ads),
      rewardedVideo: flag(features, 'rewardedVideo', d.rewardedVideo),
      purchase: flag(features, 'purchase', d.purchase),
      catalog: flag(features, 'catalog', d.catalog),
      minVersion: text(app, 'minVersion', d.minVersion),
      updateMessage: text(app, 'updateMessage', d.updateMessage),
      maintenanceMessage: text(app, 'maintenanceMessage', d.maintenanceMessage),
      storeUrl: text(app, 'storeUrl', d.storeUrl),
      premiumUnlockHours: count(
        rules,
        'premiumUnlockHours',
        d.premiumUnlockHours,
        1,
        720,
      ),
      freeCleanStickers: count(
        rules,
        'freeCleanStickers',
        d.freeCleanStickers,
        0,
        100,
      ),
      maxDrafts: count(rules, 'maxDrafts', d.maxDrafts, 1, 200),
      homeTitle: text(copy, 'homeTitle', d.homeTitle),
      homeSubtitle: text(copy, 'homeSubtitle', d.homeSubtitle),
      creatorTitle: text(copy, 'creatorTitle', d.creatorTitle),
      creatorSubtitle: text(copy, 'creatorSubtitle', d.creatorSubtitle),
      catalogTitle: text(copy, 'catalogTitle', d.catalogTitle),
      catalogSubtitle: text(copy, 'catalogSubtitle', d.catalogSubtitle),
      splashTagline: text(copy, 'splashTagline', d.splashTagline),
      aboutText: text(copy, 'aboutText', d.aboutText),
      privacyUrl: text(copy, 'privacyUrl', d.privacyUrl),
      supportEmail: text(copy, 'supportEmail', d.supportEmail),
      upgradeTitle: text(upgrade, 'title', d.upgradeTitle),
      upgradeSubtitle: text(upgrade, 'subtitle', d.upgradeSubtitle),
      upgradeBenefits: benefits is List
          ? [
              for (final b in benefits)
                if (b is String && b.trim().isNotEmpty) b,
            ]
          : d.upgradeBenefits,
      productId: text(upgrade, 'productId', d.productId),
      presets: presets.isEmpty ? d.presets : presets,
      elements: elements.isEmpty ? d.elements : elements,
    );
  }

  static List<TextPreset> _presets(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final p in raw)
        if (p is Map && p['name'] is String && _hex(p['color']) != null)
          TextPreset(
            p['name'] as String,
            _hex(p['color'])!,
            p['outline'] == true,
            (p['outlineWidth'] as num?)?.toDouble() ?? 5,
            p['shadow'] == true,
            (p['shadowBlur'] as num?)?.toDouble() ?? 5,
          ),
    ];
  }

  static List<ElementSet> _elements(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map && e['category'] is String && e['emojis'] is List)
          ElementSet(e['category'] as String, [
            for (final x in e['emojis'] as List)
              if (x is String && x.isNotEmpty) x,
          ]),
    ];
  }
}

int? _hex(Object? value) {
  if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return null;
  }
  return 0xFF000000 | int.parse(value.substring(1), radix: 16);
}

int compareVersions(String a, String b) {
  // "1.2.3+45" and "1.2.3-beta" compare as 1.2.3.
  List<int> parts(String v) => [
    for (final p in v.split(RegExp(r'[+-]')).first.split('.'))
      int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
  ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}

enum BootstrapStatus { ready, offline, failed }

abstract class RemoteContent {
  static final settings = ValueNotifier(const RemoteSettings());

  static final revision = ValueNotifier<int>(0);

  /// The published release number of the content on this device (0 if none).
  /// Unlike [revision], it only changes when a newer release arrives.
  static int release = 0;

  static Map<String, dynamic>? catalogJson;

  static bool hasCache = false;

  static const skipSetupKey = 'stiksy_setup_skipped';

  static const timeout = Duration(seconds: 15);

  static String? _artDir;
  static final _builtInSha = <String, String>{};
  static Future<bool>? _inflight;
  static DateTime? _lastRefresh;

  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/content').create(recursive: true);
  }

  static File artFile(String ref) =>
      File('${_artDir ?? ''}/${ref.substring('file:'.length)}');

  static bool needsFirstSetup(SharedPreferences prefs) =>
      SupabaseConfig.configured &&
      !hasCache &&
      !(prefs.getBool(skipSetupKey) ?? false);

  static Future<void> loadCached() async {
    try {
      final root = await _root();
      _artDir = '${root.path}/art';
      var file = File('${root.path}/manifest.json');
      final merged = await file.exists();
      if (!merged) {
        file = File('${root.path}/content.json');
        if (!await file.exists()) return;
      }
      await apply(jsonDecode(await file.readAsString()), now: DateTime.now());
      hasCache = merged;
    } catch (_) {
      // A corrupt cache just means the built-in content stays.
    }
  }

  static Future<bool> refresh({
    bool force = false,
    bool artInBackground = false,
    void Function(double progress)? onArt,
  }) {
    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return Future.value(true);
    }
    return _inflight ??= _refresh(onArt, artInBackground)
        .then((ok) {
          if (ok) _lastRefresh = DateTime.now();
          return ok;
        })
        .whenComplete(() => _inflight = null);
  }

  static Future<bool> _refresh(
    void Function(double)? onArt,
    bool artInBackground,
  ) async {
    try {
      if (!SupabaseConfig.configured) return false;
      await CatalogService.initialize();
      final json = await _download();
      if (json == null) return false;
      final root = await _root();
      _artDir = '${root.path}/art';
      final partial = File('${root.path}/manifest.json.part');
      await partial.writeAsString(jsonEncode(json), flush: true);
      await partial.rename('${root.path}/manifest.json');
      final legacy = File('${root.path}/content.json');
      if (await legacy.exists()) await legacy.delete();
      hasCache = true;
      await apply(json, now: DateTime.now());
      if (artInBackground) {
        // Built-in pictures show until the new ones arrive.
        unawaited(
          _fetchArt(json, null)
              .then((fetched) async {
                if (fetched) await apply(json, now: DateTime.now());
              })
              .catchError((_) {}),
        );
      } else if (await _fetchArt(json, onArt)) {
        await apply(json, now: DateTime.now());
      }
      return true;
    } catch (_) {
      return false; // Offline or timed out: keep showing what we have.
    }
  }

  static Future<Map<String, dynamic>?> _download() async {
    try {
      final bytes = await CatalogService.downloadPublished('manifest.json');
      final json = jsonDecode(utf8.decode(bytes));
      return isManifest(json) ? Map<String, dynamic>.from(json as Map) : null;
    } catch (e) {
      if (!_isMissing(e)) rethrow;
      return _legacy();
    }
  }

  static bool _isMissing(Object e) =>
      e is StorageException &&
      (e.statusCode == '404' || e.message.toLowerCase().contains('not found'));

  static Future<Map<String, dynamic>?> _legacy() async {
    final content = jsonDecode(
      utf8.decode(await CatalogService.downloadPublished('content.json')),
    );
    final catalog = jsonDecode(
      utf8.decode(await CatalogService.downloadPublished('catalog.json')),
    );
    if (content is! Map || catalog is! Map) return null;
    return mergeLegacy(content, catalog);
  }

  @visibleForTesting
  static bool isManifest(Object? json) =>
      json is Map && json['schemaVersion'] == 2 && json['catalog'] is Map;

  @visibleForTesting
  static Map<String, dynamic> mergeLegacy(Map content, Map catalog) => {
    ...Map<String, dynamic>.from(content),
    'schemaVersion': 2,
    'catalog': Map<String, dynamic>.from(catalog),
  };

  static Future<bool> isReachable() async {
    try {
      final host = Uri.parse(SupabaseConfig.url).host;
      final found = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 6));
      return found.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<BootstrapStatus> bootstrap(
    void Function(double progress, String label) report,
  ) async {
    if (!SupabaseConfig.configured) return BootstrapStatus.ready;
    report(0.04, 'Checking your connection…');
    if (!await isReachable()) return BootstrapStatus.offline;
    report(0.4, 'Getting the latest designs…');
    // Only the small manifest is waited for. Pictures and pack covers keep
    // downloading after the app opens, so a new user is never kept waiting.
    final ok = await refresh(force: true, artInBackground: true);
    if (!ok) return BootstrapStatus.failed;
    unawaited(
      CatalogService.prefetchCovers(
        CatalogService.parsePacks(catalogJson),
      ).catchError((_) {}),
    );
    report(1, 'All set');
    return BootstrapStatus.ready;
  }

  static Future<bool> _fetchArt(
    Map json,
    void Function(double)? onProgress,
  ) async {
    final dir = Directory(_artDir!);
    await dir.create(recursive: true);
    final todo = <(String, String)>[]; // (sha256, path)
    for (final t in (json['templates'] as List? ?? const [])) {
      final art = t is Map ? t['art'] : null;
      if (art is! Map) continue;
      final sha = art['sha256'];
      final path = art['path'];
      if (sha is! String || path is! String) continue;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha) ||
          !RegExp(r'^templates/[A-Za-z0-9_-]{1,64}\.webp$').hasMatch(path)) {
        continue;
      }
      if (await File('${dir.path}/$sha.webp').exists()) continue;
      todo.add((sha, path));
    }
    var fetched = false;
    for (var i = 0; i < todo.length; i++) {
      final (sha, path) = todo[i];
      try {
        final bytes = await CatalogService.downloadPublished(path);
        if (sha256.convert(bytes).toString() == sha) {
          await File('${dir.path}/$sha.webp').writeAsBytes(bytes, flush: true);
          fetched = true;
        }
      } catch (_) {}
      onProgress?.call((i + 1) / todo.length);
    }
    if (todo.isEmpty) onProgress?.call(1);
    return fetched;
  }

  @visibleForTesting
  static void reset() {
    catalogJson = null;
    hasCache = false;
    release = 0;
    _inflight = null;
    _lastRefresh = null;
    _artDir = null;
  }

  @visibleForTesting
  static Future<void> apply(Object? json, {required DateTime now}) async {
    if (json is! Map) return;
    release = int.tryParse('${json['version']}') ?? release;
    settings.value = RemoteSettings.fromJson(json['settings']);
    if (json['catalog'] is Map) {
      catalogJson = Map<String, dynamic>.from(json['catalog'] as Map);
    }

    final templates = await parseTemplates(json['templates'], now);
    if (templates.isNotEmpty) templatesNotifier.value = templates;

    final cats = [
      for (final c in (json['categories'] as List? ?? const []))
        if (c is Map &&
            c['name'] is String &&
            _live(c['startsAt'], c['endsAt'], now))
          c['name'] as String,
    ];
    if (cats.isNotEmpty) categoriesNotifier.value = ['All', ...cats];
    revision.value++;
  }

  static bool _live(Object? start, Object? end, DateTime now) {
    final s = start is String ? DateTime.tryParse(start) : null;
    final e = end is String ? DateTime.tryParse(end) : null;
    if (s != null && now.isBefore(s)) return false;
    if (e != null && !now.isBefore(e)) return false;
    return true;
  }

  @visibleForTesting
  static Future<List<StickerTemplate>> parseTemplates(
    Object? raw,
    DateTime now,
  ) async {
    if (raw is! List) return const [];
    final builtIn = {for (final t in builtInTemplates) t.id: t};
    final result = <StickerTemplate>[];
    for (final t in raw) {
      if (t is! Map) continue;
      final id = t['id'], title = t['title'], category = t['category'];
      final color = _hex(t['color']);
      if (id is! String ||
          title is! String ||
          category is! String ||
          color == null) {
        continue;
      }
      if (!_live(t['startsAt'], t['endsAt'], now)) continue;
      result.add(
        StickerTemplate(
          id,
          title,
          category,
          t['text'] is String ? t['text'] as String : '',
          t['emoji'] is String ? t['emoji'] as String : '',
          Color(color),
          premium: t['premium'] == true,
          asset: await _artRef(id, t['art'], builtIn[id]?.asset),
        ),
      );
    }
    return result;
  }

  static Future<String?> _artRef(
    String id,
    Object? art,
    String? bundled,
  ) async {
    if (art is! Map || art['sha256'] is! String) return bundled;
    final sha = art['sha256'] as String;
    if (bundled != null && await _bundledSha(bundled) == sha) return bundled;
    final dir = _artDir;
    if (dir != null && File('$dir/$sha.webp').existsSync()) {
      return 'file:$sha.webp';
    }
    return bundled; // Not downloaded yet: show what we have until it arrives.
  }

  static Future<String> _bundledSha(String asset) async {
    final known = _builtInSha[asset];
    if (known != null) return known;
    try {
      final data = await rootBundle.load(asset);
      return _builtInSha[asset] = sha256
          .convert(data.buffer.asUint8List())
          .toString();
    } catch (_) {
      return '';
    }
  }
}
