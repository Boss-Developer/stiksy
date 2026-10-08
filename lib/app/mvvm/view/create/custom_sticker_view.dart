import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/sticker_renderer.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../model/sticker_template.dart';
import '../../model/editor_layer.dart';
import '../editor/sticker_editor_view.dart';

const customStickerTemplate = StickerTemplate(
  'custom',
  'My sticker',
  'Custom',
  '',
  '',
  Color(0xffe9f1eb),
);

Future<String?> askForEmoji(BuildContext context) async {
  final input = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Your emoji, your sticker'),
      content: TextField(
        controller: input,
        autofocus: true,
        style: const TextStyle(
          fontSize: 36,
          fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
        ),
        decoration: const InputDecoration(
          hintText: '😎',
          helperText: 'Type or paste an emoji from your keyboard',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = input.text.trim();
            if (value.isNotEmpty) Navigator.pop(c, value.characters.first);
          },
          child: const Text('Use emoji'),
        ),
      ],
    ),
  );
  // Dispose after the closing route animation has released its text field.
  Future.delayed(const Duration(milliseconds: 400), input.dispose);
  return result;
}

class CustomStickerView extends StatefulWidget {
  const CustomStickerView({super.key});
  @override
  State<CustomStickerView> createState() => _CustomStickerViewState();
}

class _CustomStickerViewState extends State<CustomStickerView> {
  bool busy = false;
  void open(EditorLayer? layer) => Get.to(
    () => StickerEditorView(
      template: customStickerTemplate,
      initialDesign: {
        'version': 2,
        'layers': [if (layer != null) layer.toJson()],
        'selectedId': layer?.id,
        'background': 0,
        'mode': 0,
      },
    ),
  );
  Future<void> photo() async {
    setState(() => busy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final normalized = await StickerRenderer.normalizeImage(
        await image.readAsBytes(),
      );
      if (mounted) {
        open(
          EditorLayer(
            id: 'photo-0',
            kind: 'image',
            content: base64Encode(normalized),
            width: 440,
            height: 440,
            x: 256,
            y: 256,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        'Could not open this photo. Please try another image.'.showError();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget option(
    String title,
    String detail,
    IconData icon,
    Color color,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: busy ? null : action,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create your sticker')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'A little you.\nA lot of expression.',
          style: TextStyle(
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start with something you love. Add text, layers and a background, then save or share.',
          style: TextStyle(color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 30),
        option(
          busy ? 'Preparing photo…' : 'From a photo',
          'Your gallery, your memories',
          Icons.add_photo_alternate_outlined,
          const Color(0xff087653),
          photo,
        ),
        option(
          'From any emoji',
          'Use your keyboard or paste an emoji',
          Icons.sentiment_very_satisfied_rounded,
          const Color(0xffb87e29),
          () async {
            final emoji = await askForEmoji(context);
            if (emoji != null && mounted) {
              open(
                EditorLayer(
                  id: 'emoji-0',
                  kind: 'emoji',
                  content: emoji,
                  width: 410,
                  height: 410,
                  x: 256,
                  y: 256,
                ),
              );
            }
          },
        ),
        option(
          'Start with text',
          'Urdu, English or your own words',
          Icons.text_fields_rounded,
          const Color(0xff8661a5),
          () => open(
            EditorLayer(
              id: 'text-0',
              kind: 'text',
              content: 'Your words',
              font: 'Poppins',
              fontSize: 48,
              width: 440,
              height: 320,
              x: 256,
              y: 256,
            ),
          ),
        ),
        TextButton(
          onPressed: () => open(null),
          child: const Text('Start with a blank canvas'),
        ),
      ],
    ),
  );
}
