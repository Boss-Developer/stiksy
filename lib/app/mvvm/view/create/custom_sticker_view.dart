import '../../../config/app_radius.dart';
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
  // Pre-filled and selected: tapping "Use emoji" always works, and anything
  // typed or pasted replaces it.
  final input = TextEditingController(text: '😎')
    ..selection = const TextSelection(baseOffset: 0, extentOffset: 2);
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
          helperText: 'Type or paste an emoji',
          helperMaxLines: 2,
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
            Navigator.pop(c, value.isEmpty ? '😎' : value.characters.first);
          },
          child: const Text('Use emoji'),
        ),
      ],
    ),
  );
  Future.delayed(const Duration(milliseconds: 400), input.dispose);
  return result;
}

void _openEditor(EditorLayer? layer) => Get.to(
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

Future<void> startFromPhoto() async {
  try {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image == null) return;
    final normalized = await StickerRenderer.normalizeImage(
      await image.readAsBytes(),
    );
    _openEditor(
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
  } catch (_) {
    'Could not open this photo. Please try another image.'.showError();
  }
}

Future<void> startFromEmoji(BuildContext context) async {
  final emoji = await askForEmoji(context);
  if (emoji == null) return;
  _openEditor(
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

void startFromText() => _openEditor(
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
);

void startBlank() => _openEditor(null);

Future<void> showCreateSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) {
    Widget option(
      IconData icon,
      String title,
      String detail,
      VoidCallback action,
    ) => ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xffe8f5ee),
          borderRadius: AppRadius.mdAll,
        ),
        child: Icon(icon, color: const Color(0xff059669)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail),
      onTap: () {
        Navigator.pop(sheet);
        action();
      },
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Start with…',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            option(
              Icons.add_photo_alternate_outlined,
              'From a photo',
              'Your gallery, your memories',
              startFromPhoto,
            ),
            option(
              Icons.sentiment_very_satisfied_rounded,
              'From any emoji',
              'Use your keyboard or paste an emoji',
              () => startFromEmoji(context),
            ),
            option(
              Icons.text_fields_rounded,
              'Start with text',
              'Urdu, English or your own words',
              startFromText,
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(sheet);
                startBlank();
              },
              child: const Text('Start with a blank canvas'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);
