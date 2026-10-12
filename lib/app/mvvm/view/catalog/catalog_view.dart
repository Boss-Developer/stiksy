import '../../../custom_widgets/stiksy_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_colors.dart';

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

  String query = '';
  String category = 'All';
  final savedChecks = <String, Future<bool>>{};

  void reload() => setState(() {
    packs = CatalogService.loadCatalog();
    downloaded.clear();
    savedChecks.clear();
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
    appBar: AppBar(
      title: const Text('Sticker catalog'),
      actions: [
        IconButton(
          tooltip: 'Refresh catalog',
          onPressed: reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<List<CatalogPack>>(
      future: packs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: StiksyLoader(label: 'Finding your next favorite stickers…'),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: AppColors.textLightBlack,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Couldn’t load the catalog',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: reload,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final all = snapshot.data ?? [];
        final categories = ['All', ...all.map((p) => p.category).toSet()];
        final selected = categories.contains(category) ? category : 'All';
        final items = all
            .where(
              (p) =>
                  (selected == 'All' || p.category == selected) &&
                  '${p.title} ${p.category}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await packs;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff123f31),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'A LITTLE DESI. A LOT OF FEELING.',
                                style: TextStyle(
                                  color: Color(0xffb8ddca),
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Your chats,\nwith a desi twist.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${all.length} packs · Save once, send anytime',
                                style: const TextStyle(
                                  color: Color(0xffc7dfd2),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (MediaQuery.sizeOf(context).width >= 360)
                          Transform.rotate(
                            angle: .12,
                            child: Image.asset(
                              'assets/stickers/mood-cat.webp',
                              width: 88,
                              height: 112,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: (v) => setState(() => query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Find your next favorite pack',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: selected == c,
                                showCheckmark: false,
                                selectedColor: AppColors.primaryLight,
                                onSelected: (_) => setState(() => category = c),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Explore packs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${items.length} packs',
                        style: const TextStyle(
                          color: AppColors.textLightBlack,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textLightBlack,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No packs found. Try another search or category.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 720
                            ? 3
                            : constraints.maxWidth >= 340
                            ? 2
                            : 1,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 320,
                      ),
                      itemBuilder: (_, i) => _tile(items[i], i),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _tile(CatalogPack pack, int index) {
    final busy = progress[pack.id];
    const tones = [
      Color(0xffe9f4ed),
      Color(0xfffff0dd),
      Color(0xffeeebfa),
      Color(0xffe8f1fb),
    ];
    return FutureBuilder<bool>(
      future: downloaded.contains(pack.id)
          ? Future.value(true)
          : savedChecks.putIfAbsent(
              pack.id,
              () => CatalogService.isDownloaded(pack),
            ),
      builder: (context, saved) {
        final ready = saved.data == true;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tones[index % tones.length],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Cover(pack)),
                      if (ready)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Tooltip(
                            message: 'Saved for offline use',
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pack.category.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                pack.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${pack.stickerCount} stickers · ${ready ? 'Saved offline' : '${(pack.downloadBytes / 1024).round()} KB'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLightBlack,
                ),
              ),
              const SizedBox(height: 12),
              if (busy != null)
                SizedBox(
                  height: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StiksyLoader(
                        compact: true,
                        value: busy == 0 ? null : busy,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Downloading${busy > 0 ? ' ${(busy * 100).round()}%' : '…'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: ready
                            ? () => addToWhatsApp(pack)
                            : saved.connectionState == ConnectionState.done
                            ? () => download(pack)
                            : null,
                        child: FittedBox(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ready
                                    ? Icons.add_rounded
                                    : Icons.download_rounded,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(ready ? 'WhatsApp' : 'Download'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (ready)
                      PopupMenuButton<String>(
                        tooltip: 'Pack options',
                        onSelected: (v) async {
                          if (v == 'remove') {
                            try {
                              await CatalogService.remove(pack);
                              if (!mounted) return;
                              setState(() {
                                downloaded.remove(pack.id);
                                savedChecks.remove(pack.id);
                              });
                            } catch (_) {
                              if (mounted) {
                                'Unable to remove this download.'.showError();
                              }
                            }
                          } else {
                            await addToWhatsApp(pack, business: true);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'business',
                            child: Text('Add to WhatsApp Business'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove download'),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Cover extends StatefulWidget {
  const _Cover(this.pack);
  final CatalogPack pack;
  @override
  State<_Cover> createState() => _CoverState();
}

class _CoverState extends State<_Cover> {
  late Future<Uint8List?> cover = CatalogService.cover(widget.pack);
  @override
  void didUpdateWidget(covariant _Cover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pack.id != widget.pack.id ||
        oldWidget.pack.version != widget.pack.version) {
      cover = CatalogService.cover(widget.pack);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: cover,
    builder: (_, s) => s.hasData
        ? Image.memory(s.data!, fit: BoxFit.contain)
        : Icon(
            s.hasError
                ? Icons.image_not_supported_outlined
                : Icons.collections_outlined,
            size: 40,
            color: AppColors.primary.withValues(alpha: .4),
          ),
  );
}
