import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalStickerPack {
  LocalStickerPack.fromJson(String json)
    : data = jsonDecode(json) as Map<String, dynamic>;
  final Map<String, dynamic> data;
  String get id => data['identifier'] as String;
  String get name => data['name'] as String;
  int get count => (data['stickers'] as List).length;
  bool get ready => count >= 3 && count <= 30;
}

abstract class StickerExportService {
  static const channel = MethodChannel('stiksy/stickers');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<Uint8List> encode(Uint8List png) async {
    final bytes = await channel.invokeMethod<Uint8List>('encodeWebP', {
      'png': png,
    });
    if (bytes == null || bytes.length >= 100 * 1024) {
      throw PlatformException(
        code: 'invalid_webp',
        message: 'Unable to fit this sticker under 100 KB.',
      );
    }
    return bytes;
  }

  static Future<List<LocalStickerPack>> packs() async =>
      (await channel.invokeListMethod<String>('listPacks') ?? [])
          .map(LocalStickerPack.fromJson)
          .toList();
  static Future<LocalStickerPack> createPack(String name) async =>
      LocalStickerPack.fromJson(
        (await channel.invokeMethod<String>('createPack', {
          'name': name.trim(),
        }))!,
      );
  static Future<LocalStickerPack> addSticker(
    LocalStickerPack pack,
    Uint8List bytes,
    String text,
  ) async => LocalStickerPack.fromJson(
    (await channel.invokeMethod<String>('addSticker', {
      'id': pack.id,
      'bytes': bytes,
      'text': text,
    }))!,
  );
  static Future<Map<String, dynamic>> addToWhatsApp(
    LocalStickerPack pack, {
    bool business = false,
  }) async {
    if (!pack.ready) {
      throw PlatformException(
        code: 'pack_count',
        message:
            'Save at least 3 stickers in ${pack.name} first (${pack.count}/3).',
      );
    }
    final result = await channel.invokeMapMethod<String, dynamic>(
      'addToWhatsApp',
      {'id': pack.id, 'business': business},
    );
    return result ?? {'status': 'cancelled'};
  }

  static Future<void> shareToWhatsApp(
    Uint8List bytes, {
    bool business = false,
  }) => channel.invokeMethod('shareToWhatsApp', {
    'bytes': bytes,
    'business': business,
  });
  static Future<Map<String, bool>> availableWhatsApp() async =>
      await channel.invokeMapMethod<String, bool>('availableWhatsApp') ?? {};
  static Future<void> copySticker(Uint8List bytes) =>
      channel.invokeMethod('copySticker', {'bytes': bytes});
  static Future<Uint8List?> readSticker(LocalStickerPack pack, String file) =>
      channel.invokeMethod<Uint8List>('readSticker', {
        'id': pack.id,
        'file': file,
      });
  static Future<LocalStickerPack> renamePack(
    LocalStickerPack pack,
    String name,
  ) async => LocalStickerPack.fromJson(
    (await channel.invokeMethod<String>('renamePack', {
      'id': pack.id,
      'name': name,
    }))!,
  );
  static Future<LocalStickerPack> removeSticker(
    LocalStickerPack pack,
    String file,
  ) async => LocalStickerPack.fromJson(
    (await channel.invokeMethod<String>('removeSticker', {
      'id': pack.id,
      'file': file,
    }))!,
  );
  static Future<void> deletePack(LocalStickerPack pack) =>
      channel.invokeMethod('deletePack', {'id': pack.id});
  static Future<void> saveToGallery(Uint8List bytes) async {
    try {
      await channel.invokeMethod('saveToGallery', {'bytes': bytes});
    } on PlatformException catch (e) {
      if (e.code != 'gallery_permission') rethrow;
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw PlatformException(
          code: 'gallery_denied',
          message: 'Storage permission is needed to save this sticker.',
        );
      }
      await channel.invokeMethod('saveToGallery', {'bytes': bytes});
    }
  }
}
