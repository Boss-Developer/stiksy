import '../../../config/app_radius.dart';
import '../../../custom_widgets/stiksy_loader.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../../services/ad_service.dart';
import '../../../services/sticker_export_service.dart';
import '../../../services/purchase_service.dart';
import '../../../services/remote_content.dart';
import '../../../services/sticker_renderer.dart';
import '../../../services/catalog_service.dart';
import '../../../services/happy_moments.dart';
import '../../../services/reward_prompt.dart';
import '../../../services/template_access.dart';
import '../../../services/user_messages.dart';
import '../../model/sticker_template.dart';
import '../create/custom_sticker_view.dart';
import '../premium/upgrade_view.dart';

class ExportStickerView extends StatefulWidget {
  const ExportStickerView({
    super.key,
    required this.bytes,
    required this.text,
    this.template,
  });
  final Uint8List bytes;
  final String text;

  /// The design this sticker came from; a video unlock for it also covers
  /// the watermark.
  final StickerTemplate? template;
  @override
  State<ExportStickerView> createState() => _ExportStickerViewState();
}

class _ExportStickerViewState extends State<ExportStickerView> {
  Uint8List? png, webp;
  bool busy = true, business = false;
  late bool watermarked;

  /// This sticker is one of the new user's free, unmarked ones.
  bool freebie = false;
  bool freebieCounted = false;
  int freeLeft = 0;
  String? error;
  int generation = 0;
  bool detectedTargets = false;
  bool hasWhatsApp = true;
  @override
  void initState() {
    super.initState();
    final marks =
        !PurchaseService.unlocked.value &&
        RemoteContent.settings.value.rewardedVideo &&
        AdService.supported &&
        !TemplateAccess.unlockedByVideo(widget.template);
    freeLeft = marks ? TemplateAccess.freeCleanLeft : 0;
    freebie = freeLeft > 0;
    watermarked = marks && !freebie;
    prepare();
  }

  bool counted = false;

  /// Set after the pack celebration, or once the user has moved on to the
  /// next sticker: no sales sheet may follow either.
  bool celebrated = false;

  /// Counts the sticker (and a free one) once the user actually takes it, not
  /// when they only look at the screen.
  Future<void> taken() async {
    if (!counted) {
      counted = true;
      await HappyMoments.stickerTaken();
    }
    if (!freebie || freebieCounted) return;
    freebieCounted = true;
    await TemplateAccess.useFreeClean();
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
      if (!detectedTargets && StickerExportService.supported) {
        detectedTargets = true;
        final targets = await StickerExportService.availableWhatsApp();
        business = targets['whatsapp'] != true && targets['business'] == true;
        hasWhatsApp =
            targets['whatsapp'] == true || targets['business'] == true;
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

  String message(Object e) => friendlyError(
    e,
    'Something went wrong with this sticker. Please try again.',
  );
  void notify(String text) {
    if (mounted) {
      text.showInfo();
    }
  }

  void celebrate(String text) {
    if (mounted) {
      text.showSuccess();
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && counted && !celebrated) {
        await HappyMoments.offerUpgradeIfDue();
      }
    } catch (e) {
      if (mounted) message(e).showError();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> shareImage() => run(() async {
    final box = context.findRenderObject() as RenderBox?;
    await taken();
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

  Future<void> openUpgrade() async {
    await Get.to(() => const UpgradeView());
    if (mounted && PurchaseService.unlocked.value && watermarked) {
      watermarked = false;
      await prepare();
    }
  }

  Future<void> removeWatermark() async {
    await run(() async {
      if (!await watchForReward(context, unlock: 'remove the watermark') ||
          !mounted) {
        return;
      }
      watermarked = false;
      await prepare();
    });
  }

  static const _lastPackKey = 'stiksy_last_pack';

  /// Only the user's own packs: downloaded catalog packs are rebuilt when
  /// they update, which would silently delete a sticker added to them.
  Future<LocalStickerPack?> choosePack(List<LocalStickerPack> packs) async {
    final prefs = Get.find<SharedPreferences>();
    final catalog = CatalogService.linkedLocalPackIds(prefs);
    final own = packs.where((p) => !catalog.contains(p.id)).toList();
    final open = own.where((p) => p.count < 30).toList();
    // First sticker, or every pack full: start the next pack without asking.
    if (open.isEmpty) {
      return StickerExportService.createPack(
        own.isEmpty ? 'My Creations' : 'My Creations ${own.length + 1}',
      );
    }
    if (open.length == 1) return open.first;
    final lastId = prefs.getString(_lastPackKey);
    final last = open.where((p) => p.id == lastId).firstOrNull;
    if (last != null) return last;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Which pack?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...open.map(
              (p) => ListTile(
                title: Text(p.name),
                subtitle: Text('${p.count}/30 stickers'),
                trailing: const Icon(Icons.add),
                onTap: () => Navigator.pop(c, p),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New pack'),
              onTap: () => Navigator.pop(c, 'new'),
            ),
          ],
        ),
      ),
    );
    if (choice is LocalStickerPack) return choice;
    if (choice != 'new' || !mounted) return null;
    final name = await askPackName();
    return name == null ? null : StickerExportService.createPack(name);
  }

  Future<String?> askPackName() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Name your pack'),
        content: TextField(
          controller: input,
          maxLength: 32,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Family, Office'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = input.text.trim();
              Navigator.pop(c, text.isEmpty ? 'My Creations' : text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), input.dispose);
    return name;
  }

  Future<String?> showPackProgress(LocalStickerPack pack) {
    final needed = 3 - pack.count;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pack.ready ? 'Added to ${pack.name}' : 'Nice! Keep going',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pack.ready
                    ? '${pack.count} stickers · ready for WhatsApp'
                    : '${pack.count} of 3 stickers in ${pack.name}. '
                          'WhatsApp packs need at least 3, so make $needed more '
                          'and you can add the pack.\n\n'
                          'Just want to send this one? Use “Send to WhatsApp”.',
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              if (!pack.ready) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: AppRadius.xsAll,
                  child: LinearProgressIndicator(
                    value: pack.count / 3,
                    minHeight: 8,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (pack.ready) ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Navigator.pop(c, 'install'),
                  child: Text(
                    business ? 'Add to WhatsApp Business' : 'Add to WhatsApp',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Navigator.pop(c, 'more'),
                  child: const Text('Make another sticker'),
                ),
              ] else
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Navigator.pop(c, 'more'),
                  child: const Text('Make another sticker'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addToPack() async {
    await run(() async {
      final packs = await StickerExportService.packs();
      if (!mounted) return;
      final selected = await choosePack(packs);
      if (selected == null) return;
      await taken();
      final updated = await StickerExportService.addSticker(
        selected,
        webp!,
        widget.text,
      );
      await Get.find<SharedPreferences>().setString(_lastPackKey, updated.id);
      if (!mounted) return;
      final next = await showPackProgress(updated);
      if (next == 'install') {
        final result = await StickerExportService.addToWhatsApp(
          updated,
          business: business,
        );
        celebrated = result['status'] == 'added';
        if (mounted) await showPackResult(result);
      } else if (next == 'more') {
        // Back to Home, then straight into choosing the next sticker's start.
        // The user is busy again, so nothing may pop up over the next one.
        celebrated = true;
        Get.until((route) => route.isFirst);
        await showCreateSheet(Get.context!);
      }
    });
  }

  bool get ready => !busy && error == null && png != null;
  bool get canWhatsApp =>
      ready && StickerExportService.supported && webp != null;

  Future<void> sendToWhatsApp() => run(() async {
    await taken();
    await StickerExportService.shareToWhatsApp(webp!, business: business);
  });

  Future<void> saveImage() => run(() async {
    await taken();
    await StickerExportService.saveToGallery(webp!);
    celebrate('Saved to your gallery (Pictures/Stiksy).');
  });

  Future<void> copyImage() => run(() async {
    await taken();
    await StickerExportService.copySticker(webp!);
    celebrate('Sticker copied. Paste it into any chat.');
  });

  Future<void> copyText() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    celebrate('Text copied.');
  }

  Widget quickAction(IconData icon, String label, VoidCallback? onTap) =>
      Expanded(
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Opacity(
              opacity: onTap == null ? .4 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: AppColors.textDarkColor),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Your sticker is ready',
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
              // Capped so the primary actions stay on screen on small phones.
              Center(
                child: SizedBox.square(
                  dimension: 260,
                  child: ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: CustomPaint(
                      painter: StickerCheckerPainter(),
                      child: Image.memory(
                        png ?? widget.bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (busy) const StiksyLoader(compact: true),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: prepare, child: const Text('Try again')),
              ],
              const SizedBox(height: 8),
              if (StickerExportService.supported && hasWhatsApp) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: canWhatsApp ? sendToWhatsApp : null,
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(
                    business ? 'Send to WhatsApp Business' : 'Send to WhatsApp',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: canWhatsApp ? addToPack : null,
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Add to my sticker pack'),
                ),
              ] else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: ready ? shareImage : null,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share sticker'),
                ),
              if (watermarked) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xffe8f5ee),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.water_drop_outlined,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This sticker has a small Stiksy mark. One short video removes it.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (RemoteContent.settings.value.purchase)
                              TextButton(
                                onPressed: busy ? null : openUpgrade,
                                child: const Text('Remove for good'),
                              ),
                            FilledButton.tonal(
                              onPressed: busy || error != null
                                  ? null
                                  : removeWatermark,
                              child: const Text('Watch video'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (freebie) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xffe8f5ee),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          freeLeft > 1
                              ? 'Welcome gift: no watermark on this one. '
                                    '${freeLeft - 1} more free after this.'
                              : 'Welcome gift: your last free sticker '
                                    'without a watermark.',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  if (StickerExportService.supported)
                    quickAction(
                      Icons.download_outlined,
                      'Save',
                      canWhatsApp ? saveImage : null,
                    ),
                  quickAction(
                    Icons.share_outlined,
                    'Share',
                    ready ? shareImage : null,
                  ),
                  if (StickerExportService.supported)
                    quickAction(
                      Icons.image_outlined,
                      'Copy image',
                      canWhatsApp ? copyImage : null,
                    ),
                  if (widget.text.trim().isNotEmpty)
                    quickAction(Icons.copy_outlined, 'Copy text', copyText),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
