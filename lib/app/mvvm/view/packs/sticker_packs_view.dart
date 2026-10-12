import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/stiksy_loader.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../services/sticker_export_service.dart';
import '../../../services/template_access.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../model/sticker_template.dart';
import '../editor/sticker_editor_view.dart';
import '../create/custom_sticker_view.dart';
import 'sticker_pack_detail_view.dart';

class StickerPacksView extends StatefulWidget {
  const StickerPacksView({super.key});
  @override
  State<StickerPacksView> createState() => _StickerPacksViewState();
}

class _StickerPacksViewState extends State<StickerPacksView> {
  final prefs = Get.find<SharedPreferences>();
  List<LocalStickerPack> nativePacks = [];
  bool loadingPacks = false;
  @override
  void initState() {
    super.initState();
    refreshPacks();
  }

  Future<void> refreshPacks() async {
    if (!StickerExportService.supported) return;
    setState(() => loadingPacks = true);
    try {
      if (!(prefs.getBool('stiksy_packs_migrated') ?? false)) {
        final oldNames = prefs.getStringList('stiksy_packs') ?? [];
        final existing = await StickerExportService.packs();
        for (final name in oldNames) {
          if (!existing.any((p) => p.name == name)) {
            existing.add(await StickerExportService.createPack(name));
          }
        }
        await prefs.setBool('stiksy_packs_migrated', true);
      }
      final values = await StickerExportService.packs();
      if (mounted) setState(() => nativePacks = values);
    } catch (_) {
      /* The Android bridge is unavailable in widget tests and other platforms. */
    } finally {
      if (mounted) setState(() => loadingPacks = false);
    }
  }

  void notify(String text) {
    if (mounted) {
      text.showInfo();
    }
  }

  Future<void> install(LocalStickerPack pack, bool business) async {
    try {
      final result = await StickerExportService.addToWhatsApp(
        pack,
        business: business,
      );
      notify(
        result['status'] == 'added'
            ? 'Pack added. Use WhatsApp’s sticker picker to send it.'
            : result['status'] == 'rejected'
            ? 'WhatsApp rejected this pack: ${result['message']}'
            : 'Installation cancelled. Your pack is saved.',
      );
    } catch (e) {
      notify(
        e is PlatformException
            ? e.message ?? 'Unable to add this pack.'
            : 'Unable to add this pack.',
      );
    }
  }

  Future<void> newPack() async {
    final name = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New sticker pack'),
        content: TextField(
          controller: name,
          maxLength: 32,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Pack name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(c, name.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      if (StickerExportService.supported) {
        await StickerExportService.createPack(result);
        await refreshPacks();
      } else {
        await prefs.setStringList('stiksy_packs', [
          ...?prefs.getStringList('stiksy_packs'),
          result,
        ]);
      }
    } catch (e) {
      notify(
        e is PlatformException
            ? e.message ?? 'Unable to create pack.'
            : 'Unable to create pack.',
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> rename(LocalStickerPack pack) async {
    final name = TextEditingController(text: pack.name);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename pack'),
        content: TextField(controller: name, maxLength: 32, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(c, name.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await StickerExportService.renamePack(pack, result);
      await refreshPacks();
    } catch (e) {
      notify(
        e is PlatformException
            ? e.message ?? 'Unable to rename pack.'
            : 'Unable to rename pack.',
      );
    }
  }

  Future<void> detail(LocalStickerPack pack) async {
    await Get.to(() => StickerPackDetailView(pack: pack));
    await refreshPacks();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = prefs.getStringList('stiksy_drafts') ?? [];
    final packs = prefs.getStringList('stiksy_packs') ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your sticker library',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: newPack,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Pack', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _libraryHeader(
                drafts.length,
                StickerExportService.supported
                    ? nativePacks.length
                    : packs.length,
              ),
              const SizedBox(height: 28),
              if (drafts.isNotEmpty) ...[
                const Text(
                  'Your saved designs',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...drafts.reversed.map((raw) {
                  final d = jsonDecode(raw) as Map<String, dynamic>;
                  final template = stickerTemplates.firstWhere(
                    (t) => t.id == d['template'],
                    orElse: () => customStickerTemplate,
                  );
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xfff1eadc),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          d['emoji'] as String? ?? '✦',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      title: Text(
                        (d['text'] as String? ?? '').isEmpty
                            ? 'My custom sticker'
                            : d['text'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('Saved design · tap to edit'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Get.to(
                          () => StickerEditorView(
                            template: template,
                            initialDesign: d,
                          ),
                        );
                        await refreshPacks();
                        if (mounted) setState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My packs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  Text(
                    '${StickerExportService.supported ? nativePacks.length : packs.length} collections',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLightBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (loadingPacks) const StiksyLoader(compact: true),
              if (!loadingPacks &&
                  (StickerExportService.supported
                      ? nativePacks.isEmpty
                      : packs.isEmpty))
                _emptyLibrary(),
              ...nativePacks.map(
                (pack) => Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shadowColor: const Color(0xff183d30).withValues(alpha: .08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: AppColors.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => detail(pack),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: pack.count == 0
                                    ? const Icon(
                                        Icons.style_outlined,
                                        color: AppColors.primary,
                                      )
                                    : PackStickerThumbnail(
                                        key: ValueKey(
                                          '${pack.id}-cover-${pack.data['version']}',
                                        ),
                                        pack: pack,
                                        file: pack.data['stickers'][0]['file'],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pack.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffeef4ef),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${pack.count}/30',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'whatsapp',
                                  enabled: pack.ready,
                                  child: const Text('Add to WhatsApp'),
                                ),
                                PopupMenuItem(
                                  value: 'business',
                                  enabled: pack.ready,
                                  child: const Text('Add to WhatsApp Business'),
                                ),
                                PopupMenuItem(
                                  value: 'add',
                                  child: Text('Create sticker'),
                                ),
                                PopupMenuItem(
                                  value: 'view',
                                  child: Text('View stickers'),
                                ),
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename pack'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete pack'),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'whatsapp' ||
                                    value == 'business') {
                                  await install(pack, value == 'business');
                                } else if (value == 'view') {
                                  await detail(pack);
                                } else if (value == 'rename') {
                                  await rename(pack);
                                } else if (value == 'add') {
                                  await Get.to(
                                    () => StickerEditorView(
                                      template: stickerTemplates.first,
                                    ),
                                  );
                                  await refreshPacks();
                                } else {
                                  final remove = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: Text('Delete ${pack.name}?'),
                                      content: const Text(
                                        'This removes the saved stickers in this pack from Stiksy.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (remove == true) {
                                    try {
                                      await StickerExportService.deletePack(
                                        pack,
                                      );
                                      await refreshPacks();
                                    } catch (_) {
                                      notify('Unable to delete pack.');
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        if (pack.count > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: InkWell(
                              onTap: () => detail(pack),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (pack.data['stickers'] as List)
                                    .take(4)
                                    .map(
                                      (v) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: SizedBox(
                                          width: 58,
                                          height: 58,
                                          child: PackStickerThumbnail(
                                            key: ValueKey(
                                              '${pack.id}-${v['file']}',
                                            ),
                                            pack: pack,
                                            file: v['file'],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        Text(
                          pack.ready
                              ? 'Ready for WhatsApp'
                              : 'Add ${3 - pack.count} more ${pack.count == 2 ? "sticker" : "stickers"} to install',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => detail(pack),
                                child: const Text('Open pack'),
                              ),
                            ),
                            if (pack.ready) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => install(pack, false),
                                  child: const Text('WhatsApp'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!StickerExportService.supported)
                ...packs.map(
                  (name) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.style_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(name),
                      subtitle: const Text(
                        'New pack · create your first sticker',
                      ),
                      onTap: () => Get.to(
                        () =>
                            StickerEditorView(template: stickerTemplates.first),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Find your next inspiration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A few favorites to make your own.',
                style: TextStyle(fontSize: 13, color: AppColors.textLightBlack),
              ),
              const SizedBox(height: 18),
              ...['Urdu', 'Eid / Ramadan', 'Cricket', 'Funny']
                  .asMap()
                  .entries
                  .map((entry) => _collection(entry.value, entry.key)),
              const SizedBox(height: 12),
              const Text(
                'Save exported stickers into a pack. Packs with 3–30 stickers can be installed in WhatsApp on Android.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _libraryHeader(int designs, int packs) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff264b3d), Color(0xff102a21)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff385748)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 16,
              color: Color(0xffd9c693),
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'YOUR PERSONAL COLLECTION',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.4,
                  color: Color(0xffd9c693),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Made by you.\nReady to share.',
          style: TextStyle(
            fontSize: 30,
            height: 1.12,
            letterSpacing: -.8,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Keep your creations together, one pack at a time.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xffb9cebf)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _stat('$packs', 'Sticker packs'),
            Container(
              width: 1,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.white24,
            ),
            _stat('$designs', 'Saved designs'),
          ],
        ),
      ],
    ),
  );

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            color: Color(0xffeadbb4),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xffb9cebf)),
        ),
      ],
    ),
  );

  Widget _emptyLibrary() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderColor),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xfff1eadc),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.layers_outlined,
            size: 32,
            color: Color(0xff8b7449),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your first collection starts here',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a pack and fill it with your favorite creations.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textLightBlack,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: newPack,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create your first pack'),
        ),
      ],
    ),
  );

  Widget _collection(String category, int index) {
    final templates = stickerTemplates
        .where((t) => t.category == category)
        .toList();
    const tones = [
      Color(0xfff3ecdf),
      Color(0xffe8eee1),
      Color(0xffe5edf4),
      Color(0xffeee7f2),
    ];
    final title = {
      'Urdu': 'Chai Vibes',
      'Eid / Ramadan': 'Eid Special',
      'Cricket': 'Cricket Fever',
      'Funny': 'Daily Funny',
    }[category]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tones[index],
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: -.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${templates.length} designs',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLightBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            category,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textLightBlack,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = templates[i];
                return SizedBox(
                  width: 94,
                  child: Material(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        if (await TemplateAccess.allow(context, t)) {
                          await Get.to(() => StickerEditorView(template: t));
                          await refreshPacks();
                          if (mounted) setState(() {});
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: StickerArtwork(
                          template: t,
                          showBackground: false,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap a design to make it yours',
            style: TextStyle(fontSize: 11, color: AppColors.textLightBlack),
          ),
        ],
      ),
    );
  }
}
