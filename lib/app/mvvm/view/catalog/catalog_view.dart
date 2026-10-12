import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../services/catalog_service.dart';
import '../../../services/sticker_export_service.dart';

/// Pakistani culture packs served from Supabase and cached on the device.
class CatalogView extends StatefulWidget {
  const CatalogView({super.key});
  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  late Future<List<CatalogPack>> packs = CatalogService.loadCatalog();
  final progress = <String, double>{};
  final downloaded = <String>{};

  void reload() => setState(() {
    packs = CatalogService.loadCatalog();
    downloaded.clear();
  });

  Future<void> download(CatalogPack pack) async {
    setState(() => progress[pack.id] = 0);
    try {
      await CatalogService.download(
        pack,
        onProgress: (v) {
          if (mounted) setState(() => progress[pack.id] = v);
        },
      );
      downloaded.add(pack.id);
    } catch (e) {
      if (mounted) '$e'.showError();
    } finally {
      if (mounted) setState(() => progress.remove(pack.id));
    }
  }

  /// Copies a downloaded pack into the native pack store, then asks WhatsApp.
  Future<void> addToWhatsApp(CatalogPack pack, {bool business = false}) async {
    try {
      final existing = (await StickerExportService.packs())
          .where((p) => p.name == pack.title && p.count == pack.stickerCount)
          .firstOrNull;
      var local = existing;
      if (local == null) {
        final manifest = await CatalogService.manifestOf(pack);
        final files = await CatalogService.stickerFiles(pack);
        final stickers = (manifest['stickers'] as List).cast<Map>();
        local = await StickerExportService.createPack(pack.title);
        for (var i = 0; i < files.length; i++) {
          local = await StickerExportService.addSticker(
            local!,
            await files[i].readAsBytes(),
            '${stickers[i]['caption']}',
          );
        }
      }
      final result = await StickerExportService.addToWhatsApp(
        local!,
        business: business,
      );
      if (!mounted) return;
      (result['status'] == 'added'
              ? 'Pack added. Open WhatsApp’s sticker picker to send it.'
              : result['status'] == 'rejected'
              ? 'WhatsApp rejected this pack: ${result['message']}'
              : 'Installation cancelled. Your pack is saved.')
          .showInfo();
    } catch (e) {
      if (mounted) {
        (e is PlatformException
                ? e.message ?? 'Unable to add this pack.'
                : 'Unable to add this pack.')
            .showError();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pakistani Stickers')),
    body: FutureBuilder<List<CatalogPack>>(
      future: packs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}', textAlign: TextAlign.center),
                TextButton(onPressed: reload, child: const Text('Try again')),
              ],
            ),
          );
        }
        final items = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _tile(items[i]),
        );
      },
    ),
  );

  Widget _tile(CatalogPack pack) {
    final busy = progress[pack.id];
    return FutureBuilder<bool>(
      future: downloaded.contains(pack.id)
          ? Future.value(true)
          : CatalogService.isDownloaded(pack),
      builder: (context, saved) {
        final ready = saved.data == true;
        return Card(
          child: ListTile(
            leading: _Cover(pack),
            title: Text(pack.title),
            subtitle: Text(
              '${pack.category} · ${pack.stickerCount} stickers'
              '${ready ? '' : ' · ${(pack.downloadBytes / 1024).round()} KB'}',
            ),
            trailing: busy != null
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      value: busy == 0 ? null : busy,
                      strokeWidth: 3,
                    ),
                  )
                : ready
                ? PopupMenuButton<String>(
                    tooltip: 'Pack options',
                    onSelected: (v) async {
                      if (v == 'remove') {
                        await CatalogService.remove(pack);
                        downloaded.remove(pack.id);
                        if (mounted) setState(() {});
                      } else {
                        await addToWhatsApp(pack, business: v == 'business');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'whatsapp',
                        child: Text('Add to WhatsApp'),
                      ),
                      PopupMenuItem(
                        value: 'business',
                        child: Text('Add to WhatsApp Business'),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove download'),
                      ),
                    ],
                  )
                : IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download),
                    onPressed: () => download(pack),
                  ),
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover(this.pack);
  final CatalogPack pack;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 52,
    child: FutureBuilder(
      future: CatalogService.cover(pack),
      builder: (_, s) => s.data == null
          ? const Icon(Icons.image_outlined)
          : Image.memory(s.data!, fit: BoxFit.contain),
    ),
  );
}
