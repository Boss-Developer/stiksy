import '../../../config/app_radius.dart';
import '../../../custom_widgets/stiksy_loader.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_colors.dart';

import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../services/catalog_service.dart';
import '../../../services/remote_content.dart';
import '../../../services/sticker_export_service.dart';
import '../../../services/user_messages.dart';

class CatalogView extends StatefulWidget {
  const CatalogView({super.key, this.embedded = false});

  final bool embedded;
  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  late Future<List<CatalogPack>> packs = CatalogService.loadCatalog();

  /// Packs downloaded at setup, so the first frame already shows them.
  List<CatalogPack>? initial = CatalogService.cachedPacks();
  final progress = <String, double>{};
  final downloaded = <String>{};

  String query = '';
  String category = 'All';
  final savedChecks = <String, Future<bool>>{};

  @override
  void initState() {
    super.initState();
    RemoteContent.revision.addListener(_onNewContent);
    CatalogService.warmCovers();
  }

  @override
  void dispose() {
    RemoteContent.revision.removeListener(_onNewContent);
    super.dispose();
  }

  /// A background check found a newer release: re-read it from the cache.
  void _onNewContent() {
    if (!mounted) return;
    CatalogService.warmCovers();
    setState(() {
      initial = CatalogService.cachedPacks();
      packs = CatalogService.loadCatalog();
      savedChecks.clear();
    });
  }

  void reload() => setState(() {
    packs = CatalogService.loadCatalog(force: true);
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
      if (mounted) {
        friendlyError(
          e,
          'Couldn’t download this pack. Check your internet and try again.',
        ).showError();
      }
    } finally {
      if (mounted) setState(() => progress.remove(pack.id));
    }
  }

  static const _linksKey = CatalogService.linksKey;

  Future<LocalStickerPack> _localPack(CatalogPack pack) async {
    final prefs = Get.find<SharedPreferences>();
    final links = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(_linksKey) ?? '{}') as Map,
    );
    final linked = links[pack.id] as Map?;
    final existing = await StickerExportService.packs();
    final current = linked == null
        ? null
        : existing.where((p) => p.id == linked['local']).firstOrNull;
    if (current != null &&
        linked!['version'] == pack.version &&
        current.count == pack.stickerCount) {
      return current;
    }
    if (current != null) {
      // Older versions let people add their own stickers to catalog packs.
      // A pack with extra stickers is theirs now: keep it, never delete it.
      if (current.count > pack.stickerCount) {
        await StickerExportService.renamePack(
          current,
          '${pack.title} (mine)',
        ).catchError((_) => current);
      } else {
        await StickerExportService.deletePack(current);
      }
    }
    final manifest = await CatalogService.manifestOf(pack);
    final files = await CatalogService.stickerFiles(pack);
    final stickers = (manifest['stickers'] as List).cast<Map>();
    var local = await StickerExportService.createPack(pack.title);
    try {
      for (var i = 0; i < files.length; i++) {
        local = await StickerExportService.addSticker(
          local,
          await files[i].readAsBytes(),
          '${stickers[i]['caption']}',
        );
      }
    } catch (_) {
      await StickerExportService.deletePack(local).catchError((_) {});
      rethrow;
    }
    links[pack.id] = {'local': local.id, 'version': pack.version};
    await prefs.setString(_linksKey, jsonEncode(links));
    return local;
  }

  /// Copies a downloaded pack into the native pack store, then asks WhatsApp.
  Future<void> addToWhatsApp(CatalogPack pack, {bool business = false}) async {
    try {
      final local = await _localPack(pack);
      final result = await StickerExportService.addToWhatsApp(
        local,
        business: business,
      );
      if (mounted) showPackResult(result);
    } catch (e) {
      if (mounted) {
        friendlyError(
          e,
          'Couldn’t add this pack to WhatsApp. Please try again.',
        ).showError();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('Sticker catalog')),
    body: FutureBuilder<List<CatalogPack>>(
      future: packs,
      initialData: initial,
      builder: (context, snapshot) {
        // Keep showing packs while a refresh runs; spin only with nothing to show.
        if (!snapshot.hasData && !snapshot.hasError) {
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
                      borderRadius: AppRadius.mdAll,
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
            borderRadius: AppRadius.mdAll,
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
                    borderRadius: AppRadius.mdAll,
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
                // One line, so it fits the fixed 40px slot at any text size.
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StiksyLoader(
                        compact: true,
                        value: busy == 0 ? null : busy,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Downloading${busy > 0 ? ' ${(busy * 100).round()}%' : '…'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
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
    initialData: CatalogService.coverInMemory(widget.pack),
    builder: (_, s) => s.hasData
        ? Image.memory(
            s.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // Ease in instead of popping, in case decoding takes a frame.
            frameBuilder: (_, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: child,
                  ),
          )
        : Icon(
            s.hasError
                ? Icons.image_not_supported_outlined
                : Icons.collections_outlined,
            size: 40,
            color: AppColors.primary.withValues(alpha: .4),
          ),
  );
}
