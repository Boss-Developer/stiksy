import '../../../custom_widgets/stiksy_loader.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/sticker_export_service.dart';
import '../../../config/app_colors.dart';

class PackStickerThumbnail extends StatefulWidget {
  const PackStickerThumbnail({
    super.key,
    required this.pack,
    required this.file,
  });
  final LocalStickerPack pack;
  final String file;
  @override
  State<PackStickerThumbnail> createState() => _PackStickerThumbnailState();
}

class _PackStickerThumbnailState extends State<PackStickerThumbnail> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    bytes = StickerExportService.readSticker(widget.pack, widget.file);
  }

  @override
  void didUpdateWidget(PackStickerThumbnail old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file || old.pack.id != widget.pack.id) {
      bytes = StickerExportService.readSticker(widget.pack, widget.file);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, value) {
      if (value.hasData) {
        return Image.memory(value.data!, fit: BoxFit.contain, cacheWidth: 160);
      }
      return Icon(
        value.hasError ? Icons.broken_image_outlined : Icons.style_outlined,
        color: Colors.black26,
        size: 24,
      );
    },
  );
}

class StickerPackDetailView extends StatefulWidget {
  const StickerPackDetailView({super.key, required this.pack});
  final LocalStickerPack pack;
  @override
  State<StickerPackDetailView> createState() => _StickerPackDetailViewState();
}

class _StickerPackDetailViewState extends State<StickerPackDetailView> {
  late LocalStickerPack pack;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    pack = widget.pack;
  }

  void notify(String text) {
    if (mounted) {
      text.showInfo();
    }
  }

  Future<void> remove(String file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this sticker?'),
        content: const Text('This removes it from the saved pack in Stiksy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => busy = true);
    try {
      final updated = await StickerExportService.removeSticker(pack, file);
      if (mounted) setState(() => pack = updated);
    } catch (e) {
      notify(
        e is PlatformException
            ? e.message ?? 'Unable to delete sticker.'
            : 'Unable to delete sticker.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> install(bool business) async {
    setState(() => busy = true);
    try {
      final result = await StickerExportService.addToWhatsApp(
        pack,
        business: business,
      );
      notify(
        result['status'] == 'added'
            ? 'Pack added to WhatsApp.'
            : result['status'] == 'rejected'
            ? 'WhatsApp rejected this pack: ${result['message']}'
            : 'Installation cancelled.',
      );
    } catch (e) {
      notify(
        e is PlatformException
            ? e.message ?? 'Unable to install pack.'
            : 'Unable to install pack.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(pack.name)),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          '${pack.count} stickers',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        if (busy) const StiksyLoader(compact: true),
        if (pack.count == 0)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This pack is empty. Create a sticker and choose this pack on the export screen.',
            ),
          ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: (pack.data['stickers'] as List).map((s) {
            final file = s['file'] as String;
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff2f4f3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PackStickerThumbnail(
                      key: ValueKey(file),
                      pack: pack,
                      file: file,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    tooltip: 'Delete sticker',
                    onPressed: busy ? null : () => remove(file),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy || !pack.ready ? null : () => install(false),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Add to WhatsApp'),
        ),
        TextButton(
          onPressed: busy || !pack.ready ? null : () => install(true),
          child: const Text(
            'Add to WhatsApp Business',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
        if (!pack.ready)
          const Text(
            'Save at least 3 stickers before installing this pack.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
      ],
    ),
  );
}
