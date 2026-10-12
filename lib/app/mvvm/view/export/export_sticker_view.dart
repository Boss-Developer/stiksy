import '../../../custom_widgets/stiksy_loader.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../../services/ad_service.dart';
import '../../../services/sticker_export_service.dart';
import '../../../services/sticker_renderer.dart';

class ExportStickerView extends StatefulWidget {
  const ExportStickerView({super.key, required this.bytes, required this.text});
  final Uint8List bytes;
  final String text;
  @override
  State<ExportStickerView> createState() => _ExportStickerViewState();
}

class _ExportStickerViewState extends State<ExportStickerView> {
  Uint8List? png, webp;
  bool busy = true, watermarked = true, business = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    prepare();
  }

  Future<void> prepare() async {
    final token = ++generation;
    setState(() {
      busy = true;
      error = null;
      webp = null;
    });
    try {
      final rendered = watermarked
          ? await StickerRenderer.watermark(widget.bytes)
          : widget.bytes;
      final encoded = StickerExportService.supported
          ? await StickerExportService.encode(rendered)
          : null;
      if (token == 1 && StickerExportService.supported) {
        final targets = await StickerExportService.availableWhatsApp();
        business = targets['whatsapp'] != true && targets['business'] == true;
      }
      if (mounted && generation == token) {
        setState(() {
          png = rendered;
          webp = encoded;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted && generation == token) {
        setState(() {
          error = message(e);
          busy = false;
        });
      }
    }
  }

  String message(Object e) => e is PlatformException
      ? e.message ?? 'Sticker operation failed.'
      : 'Unable to prepare this sticker. Please try again.';
  void notify(String text) {
    if (mounted) {
      text.showInfo();
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      notify(message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> shareImage() => run(() async {
    final box = context.findRenderObject() as RenderBox?;
    final bytes = webp ?? png!;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: webp != null ? 'image/webp' : 'image/png',
          ),
        ],
        fileNameOverrides: [
          webp != null ? 'stiksy-sticker.webp' : 'stiksy-sticker.png',
        ],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });
  Future<void> removeWatermark() async {
    await run(() async {
      final rewarded = await AdService.watchReward();
      if (!mounted) return;
      if (!rewarded) {
        notify(
          'No reward earned. Connect to the internet and complete the video to remove the watermark.',
        );
        return;
      }
      watermarked = false;
      await prepare();
    });
  }

  Future<void> addToPack() async {
    await run(() async {
      var packs = await StickerExportService.packs();
      if (packs.isEmpty) {
        packs = [await StickerExportService.createPack('My Creations')];
      }
      if (!mounted) return;
      final selected = await showModalBottomSheet<LocalStickerPack>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Choose sticker pack',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ...packs.map(
                (p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.count}/30 stickers'),
                  enabled: p.count < 30,
                  trailing: const Icon(Icons.add),
                  onTap: () => Navigator.pop(c, p),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      final updated = await StickerExportService.addSticker(
        selected,
        webp!,
        widget.text,
      );
      if (!mounted) return;
      if (!updated.ready) {
        notify(
          'Saved to ${updated.name} (${updated.count}/3). Add ${3 - updated.count} more ${updated.count == 2 ? "sticker" : "stickers"} to unlock WhatsApp installation.',
        );
        return;
      }
      final install = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${updated.name} is ready'),
          content: Text(
            '${updated.count} stickers. Add this pack to ${business ? "WhatsApp Business" : "WhatsApp"}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Add to WhatsApp'),
            ),
          ],
        ),
      );
      if (install != true) return;
      final result = await StickerExportService.addToWhatsApp(
        updated,
        business: business,
      );
      notify(
        result['status'] == 'added'
            ? 'Pack added. Open WhatsApp’s sticker picker to send your stickers.'
            : result['status'] == 'rejected'
            ? 'WhatsApp rejected the pack: ${result['message']}'
            : 'Pack installation cancelled. Your stickers are saved.',
      );
    });
  }

  Future<void> showWhatsAppOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .85,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Share to WhatsApp',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      painter: StickerCheckerPainter(),
                      child: Image.memory(png ?? widget.bytes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(
                      Icons.chat_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Send image to WhatsApp'),
                    subtitle: const Text('Choose a chat in WhatsApp'),
                    onTap: () {
                      Navigator.pop(sheet);
                      run(
                        () => StickerExportService.shareToWhatsApp(
                          webp!,
                          business: business,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.style_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Add to WhatsApp Sticker Pack'),
                    onTap: () {
                      Navigator.pop(sheet);
                      addToPack();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: const Text('Share to other apps'),
                    onTap: () {
                      Navigator.pop(sheet);
                      shareImage();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Save to device'),
                    onTap: () {
                      Navigator.pop(sheet);
                      run(() async {
                        await StickerExportService.saveToGallery(webp!);
                        notify('Saved to Pictures/Stiksy.');
                      });
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheet),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Export Sticker',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: StickerCheckerPainter(),
                  child: Image.memory(png ?? widget.bytes),
                ),
              ),
              const SizedBox(height: 16),
              if (busy) const StiksyLoader(compact: true),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: prepare, child: const Text('Try again')),
              ],
              check('512 × 512 px'),
              if (webp != null)
                check(
                  'WebP · ${(webp!.length / 1024).toStringAsFixed(1)} KB · under 100 KB',
                )
              else if (!StickerExportService.supported && png != null)
                check('PNG · ${(png!.length / 1024).toStringAsFixed(0)} KB'),
              check(
                watermarked
                    ? 'Free export · Stiksy watermark'
                    : 'Watermark removed for this export',
              ),
              const SizedBox(height: 16),
              if (StickerExportService.supported)
                FilledButton.icon(
                  onPressed: busy || webp == null
                      ? null
                      : () => run(() async {
                          await StickerExportService.saveToGallery(webp!);
                          notify('Saved to Pictures/Stiksy.');
                        }),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save to Gallery'),
                ),
              if (watermarked)
                TextButton.icon(
                  onPressed: busy || error != null ? null : removeWatermark,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch video · remove watermark'),
                ),
              ListTile(
                enabled: !busy && error == null && png != null,
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to other apps'),
                trailing: const Icon(Icons.chevron_right),
                onTap: shareImage,
              ),
              if (StickerExportService.supported) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use WhatsApp Business'),
                  value: business,
                  onChanged: busy ? null : (v) => setState(() => business = v),
                ),
                ListTile(
                  enabled: !busy && webp != null,
                  leading: const Icon(
                    Icons.chat_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Share image to WhatsApp'),
                  subtitle: const Text(
                    'Opens a chat share; sticker packs use the option below',
                  ),
                  onTap: showWhatsAppOptions,
                ),
                ListTile(
                  enabled: !busy && webp != null,
                  leading: const Icon(
                    Icons.style_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Add to WhatsApp Sticker Pack'),
                  subtitle: const Text(
                    'Save at least 3 stickers, then install the pack',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: addToPack,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'WhatsApp sticker-pack installation and WebP encoding are currently available on Android.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              if (StickerExportService.supported)
                ListTile(
                  enabled: !busy && webp != null,
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Copy sticker image'),
                  onTap: () => run(() async {
                    await StickerExportService.copySticker(webp!);
                    notify('Sticker image copied.');
                  }),
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text to clipboard'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.text));
                  notify('Text copied.');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget check(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
