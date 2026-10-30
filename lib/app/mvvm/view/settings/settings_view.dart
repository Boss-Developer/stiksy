import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_radius.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../custom_widgets/stiksy_crown.dart';
import '../../../services/catalog_service.dart';
import '../../../services/draft_images.dart';
import '../../../services/purchase_service.dart';
import '../../../services/remote_content.dart';
import '../premium/upgrade_view.dart';

/// Where the app lives on Google Play (used by Rate and Share).
const _playUrl =
    'https://play.google.com/store/apps/details?id=com.sfdevelopers.stiksy';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final prefs = Get.find<SharedPreferences>();
  String version = '';
  int downloadedBytes = 0;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  Future<void> _loadFacts() async {
    final info = await PackageInfo.fromPlatform();
    final bytes = await CatalogService.downloadedBytes();
    if (!mounted) return;
    setState(() {
      version = info.version;
      downloadedBytes = bytes;
    });
  }

  int get savedDesigns => (prefs.getStringList('stiksy_drafts') ?? []).length;

  static String size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && mounted) 'Couldn’t open that link.'.showError();
  }

  Future<void> _restore() async {
    await PurchaseService.restore();
    // Nothing to restore produces no store event, so answer after a moment.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    if (PurchaseService.unlocked.value) {
      'Purchase restored. Welcome back!'.showSuccess();
    } else {
      'No earlier purchase found on this account.'.showInfo();
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => checking = true);
    final before = RemoteContent.release;
    final reached = await RemoteContent.refresh(force: true);
    if (!mounted) return;
    setState(() => checking = false);
    if (!reached) {
      'Couldn’t reach the server. Check your connection.'.showError();
    } else if (RemoteContent.release != before) {
      'New content downloaded.'.showSuccess();
    } else {
      'You’re up to date.'.showInfo();
    }
  }

  Future<void> _clearDownloads() async {
    if (!await _confirm(
      'Clear downloaded packs?',
      'Frees ${size(downloadedBytes)}. Packs you already added to My Packs are kept; the catalog downloads again when you need a pack.',
      'Clear',
    )) {
      return;
    }
    await CatalogService.clearDownloads();
    await _loadFacts();
    if (mounted) 'Downloaded packs cleared.'.showSuccess();
  }

  Future<void> _clearDesigns() async {
    if (!await _confirm(
      'Delete saved designs?',
      'This removes all $savedDesigns saved designs from this device. Stickers you exported are not affected.',
      'Delete',
    )) {
      return;
    }
    await prefs.setStringList('stiksy_drafts', []);
    await DraftImages.collect(const <String>[]);
    if (!mounted) return;
    setState(() {});
    'Saved designs deleted.'.showSuccess();
  }

  void _showWhatsAppHelp() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Add stickers to WhatsApp'),
      content: const Text(
        '1. Make a sticker, then tap Next.\n'
        '2. Tap “Send to WhatsApp” and choose a pack. A pack needs at least 3 stickers.\n'
        '3. WhatsApp asks you to confirm. Tap Add.\n'
        '4. Open any chat, tap the emoji button, then the sticker tab to send.',
        style: TextStyle(height: 1.5),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(text: 'Make your own WhatsApp stickers with Stiksy: $_playUrl'),
  );

  @override
  Widget build(BuildContext context) {
    final remote = RemoteContent.settings.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (remote.purchase) ...[_premium(), const SizedBox(height: 8)],
                _section('Storage'),
                _card([
                  _row(
                    icon: Icons.sync_rounded,
                    title: 'Check for new content',
                    subtitle: 'Templates, categories and sticker packs',
                    trailing: checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : null,
                    onTap: checking ? null : _checkForUpdates,
                  ),
                  _row(
                    icon: Icons.download_done_rounded,
                    title: 'Downloaded packs',
                    subtitle: size(downloadedBytes),
                    trailing: TextButton(
                      onPressed: downloadedBytes == 0 ? null : _clearDownloads,
                      child: const Text('Clear'),
                    ),
                  ),
                  _row(
                    icon: Icons.brush_outlined,
                    title: 'Saved designs',
                    subtitle: savedDesigns == 0
                        ? 'None yet'
                        : '$savedDesigns on this device',
                    trailing: TextButton(
                      onPressed: savedDesigns == 0 ? null : _clearDesigns,
                      child: const Text('Delete'),
                    ),
                  ),
                ]),
                _section('Help'),
                _card([
                  _row(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'How to add stickers to WhatsApp',
                    onTap: _showWhatsAppHelp,
                  ),
                  if (remote.supportEmail.isNotEmpty)
                    _row(
                      icon: Icons.mail_outline_rounded,
                      title: 'Contact support',
                      subtitle: remote.supportEmail,
                      onTap: () => _open(
                        Uri(
                          scheme: 'mailto',
                          path: remote.supportEmail,
                          query:
                              'subject=${Uri.encodeComponent('Stiksy $version')}',
                        ),
                      ),
                    ),
                  if (remote.privacyUrl.isNotEmpty)
                    _row(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      onTap: () => _open(Uri.parse(remote.privacyUrl)),
                    ),
                ]),
                _section('Spread the word'),
                _card([
                  _row(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate Stiksy',
                    subtitle: 'A review helps a lot',
                    onTap: () => _open(Uri.parse(_playUrl)),
                  ),
                  _row(
                    icon: Icons.ios_share_rounded,
                    title: 'Share Stiksy with friends',
                    onTap: _share,
                  ),
                ]),
                _section('About'),
                _card([
                  _row(
                    icon: Icons.info_outline_rounded,
                    title: 'Stiksy',
                    subtitle: version.isEmpty ? null : 'Version $version',
                  ),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    remote.aboutText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textLightBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _premium() => ValueListenableBuilder<bool>(
    valueListenable: PurchaseService.unlocked,
    builder: (context, owned, _) => Material(
      color: const Color(0xff143f33),
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () => Get.to(() => const UpgradeView()),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const StiksyCrown(size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owned
                          ? 'You’re all set'
                          : RemoteContent.settings.value.upgradeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      owned
                          ? 'Ads and watermarks are gone. Thank you!'
                          : 'One payment, yours forever',
                      style: const TextStyle(
                        color: Color(0xffd7e8df),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!owned)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffe3f2b8),
                  ),
                  onPressed: _restore,
                  child: const Text('Restore'),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: AppColors.textLightBlack,
      ),
    ),
  );

  Widget _card(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.borderColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 56),
          rows[i],
        ],
      ],
    ),
  );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool stacked = false,
  }) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textLightBlack,
              ),
            ),
          ),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.primary),
                      const SizedBox(width: 16),
                      Expanded(child: text),
                    ],
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 40),
                      child: trailing,
                    ),
                ],
              )
            : Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(child: text),
                  ?trailing,
                  if (trailing == null && onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textLightBlack,
                    ),
                ],
              ),
      ),
    );
  }
}
