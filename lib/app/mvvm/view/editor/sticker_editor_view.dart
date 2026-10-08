import '../../../custom_widgets/snackbars/app_snackbar.dart';

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../../custom_widgets/sticker_background.dart';
import '../../../custom_widgets/stiksy_ads.dart';
import '../../../services/sticker_export_service.dart';
import '../../../services/sticker_renderer.dart';
import '../../model/editor_layer.dart';
import '../../model/sticker_template.dart';
import '../export/export_sticker_view.dart';
import '../create/custom_sticker_view.dart';

class StickerEditorView extends StatefulWidget {
  const StickerEditorView({
    super.key,
    required this.template,
    this.initialDesign,
  });
  final StickerTemplate template;
  final Map<String, dynamic>? initialDesign;
  @override
  State<StickerEditorView> createState() => _StickerEditorViewState();
}

class _StickerEditorViewState extends State<StickerEditorView> {
  final text = TextEditingController();
  final canvasKey = GlobalKey();
  final List<EditorLayer> layers = [];
  final List<Map<String, dynamic>> history = [];
  String? selectedId, draftId, backgroundImage;
  Color background = Colors.transparent, gradientEnd = const Color(0xff059669);
  int backgroundMode = 0,
      pattern = 1,
      cursor = -1,
      tool = 0,
      styleTab = 0,
      backgroundTab = 0;
  String elementCategory = 'All';
  StateSetter? panelUpdate;
  double startScale = 1, startRotation = 0, displayScale = 1;
  bool importing = false, exporting = false;
  static const colors = [
    Colors.transparent,
    Colors.white,
    Colors.black,
    Color(0xffef4444),
    Color(0xfff59e0b),
    Color(0xfffacc15),
    Color(0xff059669),
    Color(0xff0ea5e9),
    Color(0xff8b5cf6),
    Color(0xfff472b6),
  ];
  static const fonts = {
    'NotoNastaliqUrdu': 'Noto Nastaliq',
    'NotoNaskhArabic': 'Naskh',
    'Poppins': 'Poppins',
    'Montserrat': 'Montserrat',
    '': 'System Sans',
  };
  EditorLayer? get selected =>
      layers.where((l) => l.id == selectedId).firstOrNull;
  String identifier() => DateTime.now().microsecondsSinceEpoch.toString();
  @override
  void initState() {
    super.initState();
    if (widget.initialDesign != null) {
      apply(widget.initialDesign!);
      draftId = widget.initialDesign!['draftId'];
    } else {
      final embedded =
          widget.template.asset != null &&
          widget.template.asset != 'assets/stickers/chai.webp';
      if (!embedded) {
        layers.add(
          EditorLayer(
            id: 'text-0',
            kind: 'text',
            content: widget.template.text,
            x: widget.template.asset == 'assets/stickers/chai.webp' ? 200 : 256,
            y: widget.template.asset == 'assets/stickers/chai.webp' ? 190 : 166,
            width: 360,
            height: 280,
            fontSize: RegExp(r'[\u0600-\u06ff]').hasMatch(widget.template.text)
                ? 56
                : 40,
            font: RegExp(r'[\u0600-\u06ff]').hasMatch(widget.template.text)
                ? 'NotoNastaliqUrdu'
                : 'Poppins',
          ),
        );
      }
      layers.add(
        EditorLayer(
          id: 'element-0',
          kind: widget.template.asset == null ? 'emoji' : 'asset',
          content: widget.template.asset ?? widget.template.emoji,
          x: widget.template.asset == 'assets/stickers/chai.webp' ? 375 : 256,
          y: embedded
              ? 256
              : widget.template.asset == 'assets/stickers/chai.webp'
              ? 375
              : 338,
          width: embedded
              ? 410
              : widget.template.asset == 'assets/stickers/chai.webp'
              ? 230
              : 260,
          height: embedded
              ? 410
              : widget.template.asset == 'assets/stickers/chai.webp'
              ? 230
              : 260,
        ),
      );
      selectedId = layers.last.id;
      if (widget.template.asset == 'assets/stickers/chai.webp') {
        layers.add(
          EditorLayer(
            id: 'heart-0',
            kind: 'shape',
            content: 'heart',
            x: 426,
            y: 222,
            width: 56,
            height: 56,
            color: 0xffff7097,
          ),
        );
      }
    }
    record();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      recoverImage();
    }
  }

  Future<void> recoverImage() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.files?.isNotEmpty == true && mounted) {
        await acceptImage(response.files!.first);
      }
    } catch (_) {
      /* A cancelled picker or an unavailable test plugin leaves the design intact. */
    }
  }

  Map<String, dynamic> snapshot() => {
    'version': 2,
    'layers': layers.map((l) => l.toJson()).toList(),
    'selectedId': selectedId,
    'background': background.toARGB32(), 'gradientEnd': gradientEnd.toARGB32(),
    'backgroundMode': backgroundMode,
    'pattern': pattern,
    'backgroundImage': backgroundImage,
    // Summary fields keep existing draft cards compatible.
    'text': layers
        .where((l) => l.kind == 'text')
        .map((l) => l.content)
        .join('\n'),
    'emoji': layers
        .where((l) => l.kind == 'emoji')
        .map((l) => l.content)
        .join(' '),
  };
  void apply(Map<String, dynamic> s) {
    layers.clear();
    if (s['layers'] is List) {
      layers.addAll(
        (s['layers'] as List).map(
          (v) => EditorLayer.fromJson(Map<String, dynamic>.from(v)),
        ),
      );
    } else {
      final textLayer = EditorLayer(
        id: 'text-0',
        kind: 'text',
        content: s['text'] ?? widget.template.text,
        x: 256,
        y: 166,
        width: 380,
        height: 250,
        fontSize: (s['size'] as num?)?.toDouble() ?? 40,
        color: s['ink'] ?? 0xff302317,
        outline: s['outline'] ?? true,
        shadow: s['shadow'] ?? false,
        alignment: s['alignment'] == 0
            ? 0
            : s['alignment'] == 1
            ? 2
            : 1,
        visible: s['textVisible'] ?? true,
        locked: s['locked'] ?? false,
      );
      final e = s['emoji'] ?? widget.template.emoji;
      final asset = e == widget.template.emoji ? widget.template.asset : null;
      final element = EditorLayer(
        id: 'element-0',
        kind: asset == null ? 'emoji' : 'asset',
        content: asset ?? e,
        x: 256,
        y: 338,
        width: 260,
        height: 260,
        visible: s['elementVisible'] ?? true,
      );
      layers.addAll(
        s['elementFirst'] == true ? [element, textLayer] : [textLayer, element],
      );
    }
    selectedId = s['selectedId'] ?? layers.firstOrNull?.id;
    background = Color(s['background'] ?? 0);
    gradientEnd = Color(s['gradientEnd'] ?? 0xff059669);
    backgroundMode = s['backgroundMode'] ?? 0;
    pattern = s['pattern'] ?? 1;
    backgroundImage = s['backgroundImage'];
    syncText();
  }

  void syncText() {
    text.text = selected?.kind == 'text' ? selected!.content : '';
  }

  void record() {
    history.removeRange(cursor + 1, history.length);
    history.add(jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>);
    if (history.length > 80) history.removeAt(0);
    cursor = history.length - 1;
  }

  void change(VoidCallback action) {
    setState(() {
      action();
      record();
    });
    panelUpdate?.call(() {});
  }

  void select(EditorLayer layer) {
    setState(() {
      selectedId = layer.id;
      syncText();
    });
    panelUpdate?.call(() {});
  }

  void restore(int index) {
    setState(() {
      cursor = index;
      apply(history[index]);
    });
    panelUpdate?.call(() {});
  }

  void addText() => change(() {
    final l = EditorLayer(
      id: identifier(),
      kind: 'text',
      content: 'Your words',
      font: 'Poppins',
    );
    layers.add(l);
    selectedId = l.id;
    syncText();
  });
  void addElement(String kind, String content) => change(() {
    final l = EditorLayer(
      id: identifier(),
      kind: kind,
      content: content,
      width: 180,
      height: 180,
      x: 350,
      y: 350,
    );
    layers.add(l);
    selectedId = l.id;
  });
  void duplicate() {
    final l = selected;
    if (l == null) return;
    change(() {
      final copy = EditorLayer.fromJson(l.toJson());
      copy.id = identifier();
      copy.locked = false;
      copy.x = (copy.x + 24).clamp(40, 472);
      copy.y = (copy.y + 24).clamp(40, 472);
      layers.add(copy);
      selectedId = copy.id;
      syncText();
    });
  }

  void removeSelected() {
    final l = selected;
    if (l == null || l.locked) return;
    change(() {
      layers.remove(l);
      selectedId = layers.lastOrNull?.id;
      syncText();
    });
  }

  Future<void> save() async {
    final prefs = Get.find<SharedPreferences>();
    final drafts = prefs.getStringList('stiksy_drafts') ?? [];
    draftId ??= identifier();
    final raw = jsonEncode({
      ...snapshot(),
      'draftId': draftId,
      'template': widget.template.id,
      'savedAt': DateTime.now().toIso8601String(),
    });
    final index = drafts.indexWhere((v) => jsonDecode(v)['draftId'] == draftId);
    if (index < 0) {
      drafts.add(raw);
    } else {
      drafts[index] = raw;
    }
    await prefs.setStringList('stiksy_drafts', drafts);
    notify('Design saved on this device.');
  }

  void notify(String message) {
    if (mounted) {
      message.showInfo();
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Widget words(EditorLayer l, {bool stroke = false}) => Text(
    l.content,
    textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(l.content)
        ? TextDirection.rtl
        : TextDirection.ltr,
    textAlign: l.textAlign,
    style: TextStyle(
      fontFamily: l.font.isEmpty ? null : l.font,
      fontSize: l.fontSize,
      fontWeight: FontWeight.w700,
      height: l.lineHeight,
      color: stroke ? null : Color(l.color),
      foreground: stroke
          ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = l.outlineWidth
              ..color = Colors.white)
          : null,
      shadows: !stroke && l.shadow
          ? [
              Shadow(
                color: Colors.black45,
                blurRadius: l.shadowBlur,
                offset: const Offset(2, 3),
              ),
            ]
          : null,
    ),
  );
  Widget layerContent(EditorLayer l) {
    switch (l.kind) {
      case 'text':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [if (l.outline) words(l, stroke: true), words(l)],
          ),
        );
      case 'asset':
        return Image.asset(l.content, fit: BoxFit.contain);
      case 'image':
        return Image.memory(
          base64Decode(l.content),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      case 'shape':
        return CustomPaint(
          painter: ElementShapePainter(l.content, Color(l.color)),
        );
      default:
        return LayoutBuilder(
          builder: (context, bounds) => Center(
            child: Text(
              l.content,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: math.min(bounds.maxWidth, bounds.maxHeight) * .78,
                height: 1,
                fontFamilyFallback: const [
                  'Apple Color Emoji',
                  'Noto Color Emoji',
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget position(EditorLayer l, Widget child) => Positioned(
    left: l.x - l.width * l.scale / 2,
    top: l.y - l.height * l.scale / 2,
    width: l.width * l.scale,
    height: l.height * l.scale,
    child: Transform.rotate(angle: l.rotation, child: child),
  );
  Widget backgroundWidget() => Container(
    decoration: BoxDecoration(
      color: background,
      gradient: backgroundMode == 1
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [background, gradientEnd],
            )
          : null,
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (backgroundMode == 3 && backgroundImage != null)
          Image.memory(base64Decode(backgroundImage!), fit: BoxFit.cover),
        if (backgroundMode == 2)
          CustomPaint(painter: StickerPatternPainter(pattern, gradientEnd)),
      ],
    ),
  );
  Widget composition({bool interactive = false}) => LayoutBuilder(
    builder: (context, bounds) {
      final side = math.min(bounds.maxWidth, bounds.maxHeight);
      if (interactive) displayScale = side / 512;
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: FittedBox(
            child: SizedBox(
              width: 512,
              height: 512,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  RepaintBoundary(
                    key: interactive ? canvasKey : null,
                    child: SizedBox(
                      width: 512,
                      height: 512,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: backgroundWidget()),
                          for (final l in layers)
                            if (l.visible)
                              position(
                                l,
                                Opacity(
                                  opacity: l.opacity,
                                  child: l.kind == 'emoji'
                                      ? layerContent(l)
                                      : FittedBox(
                                          fit: BoxFit.fill,
                                          child: SizedBox(
                                            width: l.width,
                                            height: l.height,
                                            child: layerContent(l),
                                          ),
                                        ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  if (interactive)
                    for (final l in layers)
                      if (l.visible)
                        position(
                          l,
                          GestureDetector(
                            key: ValueKey('canvas-layer-${l.id}'),
                            behavior: HitTestBehavior.translucent,
                            onTap: () => select(l),
                            onScaleStart: l.locked
                                ? null
                                : (d) {
                                    select(l);
                                    startScale = l.scale;
                                    startRotation = l.rotation;
                                  },
                            onScaleUpdate: l.locked
                                ? null
                                : (d) => setState(() {
                                    l.x =
                                        (l.x +
                                                d.focalPointDelta.dx /
                                                    displayScale)
                                            .clamp(0, 512);
                                    l.y =
                                        (l.y +
                                                d.focalPointDelta.dy /
                                                    displayScale)
                                            .clamp(0, 512);
                                    l.scale = (startScale * d.scale).clamp(
                                      .2,
                                      3,
                                    );
                                    l.rotation = startRotation + d.rotation;
                                  }),
                            onScaleEnd: l.locked ? null : (_) => change(() {}),
                            child: selectedId != l.id
                                ? const SizedBox.expand()
                                : Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: SelectionBorderPainter(
                                            l.locked,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: -14,
                                        top: -14,
                                        child: handle(
                                          Icons.delete_outline,
                                          const Color(0xffff4b85),
                                          l.locked ? null : removeSelected,
                                          'Delete selected layer',
                                        ),
                                      ),
                                      Positioned(
                                        right: -14,
                                        top: -14,
                                        child: handle(
                                          l.locked ? Icons.lock : Icons.copy,
                                          AppColors.primary,
                                          duplicate,
                                          'Duplicate selected layer',
                                        ),
                                      ),
                                      Positioned(
                                        right: -14,
                                        bottom: -14,
                                        child: GestureDetector(
                                          onPanStart: l.locked
                                              ? null
                                              : (_) => startScale = l.scale,
                                          onPanUpdate: l.locked
                                              ? null
                                              : (d) => setState(
                                                  () => l.scale =
                                                      (l.scale +
                                                              d.delta.dx /
                                                                  (l.width *
                                                                      displayScale))
                                                          .clamp(.2, 3),
                                                ),
                                          onPanEnd: l.locked
                                              ? null
                                              : (_) => change(() {}),
                                          child: handle(
                                            Icons.open_in_full,
                                            AppColors.primary,
                                            null,
                                            'Resize layer',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget handle(
    IconData icon,
    Color color,
    VoidCallback? action,
    String label,
  ) => Semantics(
    label: label,
    child: GestureDetector(
      onTap: action,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    ),
  );
  Future<void> export() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final boundary =
          canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null && mounted) {
        await Get.to(
          () => ExportStickerView(
            bytes: data.buffer.asUint8List(),
            text: layers
                .where((l) => l.kind == 'text' && l.visible)
                .map((l) => l.content)
                .join('\n'),
          ),
        );
      }
    } catch (_) {
      notify('Unable to render this design. Please try again.');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> importImage({bool asBackground = false}) async {
    if (importing) return;
    setState(() => importing = true);
    panelUpdate?.call(() {});
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 65,
        requestFullMetadata: false,
      );
      if (file != null && mounted) {
        await acceptImage(file, asBackground: asBackground);
      }
    } catch (_) {
      notify('Unable to open this photo. Please choose another image.');
    } finally {
      if (mounted) setState(() => importing = false);
      panelUpdate?.call(() {});
    }
  }

  Future<void> acceptImage(XFile file, {bool asBackground = false}) async {
    var bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      notify('Choose an image smaller than 8 MB.');
      return;
    }
    bytes = await StickerRenderer.normalizeImage(bytes, cover: asBackground);
    if (!mounted) return;
    if (StickerExportService.supported) {
      bytes = await StickerExportService.encode(bytes);
    }
    if (!mounted) return;
    final encoded = base64Encode(bytes);
    if (asBackground) {
      change(() {
        backgroundImage = encoded;
        backgroundMode = 3;
        backgroundTab = 3;
      });
    } else {
      addElement('image', encoded);
    }
  }

  Widget tabs(List<String> labels, int value, void Function(int) pick) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels
              .asMap()
              .entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == value,
                    onSelected: (_) => pick(e.key),
                  ),
                ),
              )
              .toList(),
        ),
      );
  Widget swatches(
    Color current,
    void Function(Color) pick, {
    bool transparent = true,
  }) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: colors
        .where((c) => transparent || c != Colors.transparent)
        .map(
          (c) => InkWell(
            onTap: () => change(() => pick(c)),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: current == c ? AppColors.primary : Colors.black12,
                  width: current == c ? 3 : 1,
                ),
              ),
              child: c == Colors.transparent
                  ? CustomPaint(painter: StickerCheckerPainter())
                  : null,
            ),
          ),
        )
        .toList(),
  );
  Widget slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) pick, {
    bool enabled = true,
  }) => Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: enabled ? (v) => change(() => pick(v)) : null,
        ),
      ),
      SizedBox(
        width: 34,
        child: Text(
          value.toStringAsFixed(value < 2 ? 1 : 0),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
  List<Widget> textTools() {
    final l = selected;
    if (l == null || l.kind != 'text') {
      return [
        FilledButton.icon(
          onPressed: addText,
          icon: const Icon(Icons.add),
          label: const Text('Add text layer'),
        ),
      ];
    }
    final enabled = !l.locked;
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: text,
              readOnly: !enabled,
              maxLines: 2,
              maxLength: 160,
              onChanged: (v) => change(() => l.content = v),
              decoration: const InputDecoration(
                labelText: 'Your words',
                hintText: 'Urdu, English or Roman Urdu…',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add text layer',
            onPressed: addText,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      tabs(['Font', 'Color', 'Effects', 'Align'], styleTab, (v) {
        setState(() => styleTab = v);
        panelUpdate?.call(() {});
      }),
      const SizedBox(height: 14),
      if (styleTab == 0)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 135,
              child: Column(
                children: fonts.entries
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: enabled
                              ? () => change(() => l.font = f.key)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xfff6f7f8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: l.font == f.key
                                    ? const Color(0xff1685ff)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontFamily: f.key.isEmpty ? null : f.key,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f.value,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: l.font == f.key
                                          ? const Color(0xff1685ff)
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  slider(
                    'Size',
                    l.fontSize,
                    16,
                    90,
                    (v) => l.fontSize = v,
                    enabled: enabled,
                  ),
                  const Text('Text Color', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: colors
                        .where((c) => c != Colors.transparent)
                        .map(
                          (c) => InkWell(
                            onTap: enabled
                                ? () => change(() => l.color = c.toARGB32())
                                : null,
                            child: Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: l.color == c.toARGB32()
                                      ? AppColors.primary
                                      : Colors.black12,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Outline',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: l.outline,
                    onChanged: enabled
                        ? (v) => change(() => l.outline = v)
                        : null,
                  ),
                  slider(
                    'Width',
                    l.outlineWidth,
                    0,
                    12,
                    (v) => l.outlineWidth = v,
                    enabled: enabled && l.outline,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shadow', style: TextStyle(fontSize: 12)),
                    value: l.shadow,
                    onChanged: enabled
                        ? (v) => change(() => l.shadow = v)
                        : null,
                  ),
                  slider(
                    'Blur',
                    l.shadowBlur,
                    0,
                    20,
                    (v) => l.shadowBlur = v,
                    enabled: enabled && l.shadow,
                  ),
                ],
              ),
            ),
          ],
        ),
      if (styleTab == 1) ...[
        swatches(Color(l.color), (c) {
          if (enabled) l.color = c.toARGB32();
        }, transparent: false),
        slider(
          'Opacity',
          l.opacity,
          0,
          1,
          (v) => l.opacity = v,
          enabled: enabled,
        ),
      ],
      if (styleTab == 2) ...[
        SwitchListTile(
          title: const Text('Outline'),
          value: l.outline,
          onChanged: enabled ? (v) => change(() => l.outline = v) : null,
        ),
        slider(
          'Width',
          l.outlineWidth,
          0,
          12,
          (v) => l.outlineWidth = v,
          enabled: enabled && l.outline,
        ),
        SwitchListTile(
          title: const Text('Shadow'),
          value: l.shadow,
          onChanged: enabled ? (v) => change(() => l.shadow = v) : null,
        ),
        slider(
          'Blur',
          l.shadowBlur,
          0,
          20,
          (v) => l.shadowBlur = v,
          enabled: enabled && l.shadow,
        ),
        slider(
          'Rotation',
          l.rotation * 180 / math.pi,
          -180,
          180,
          (v) => l.rotation = v * math.pi / 180,
          enabled: enabled,
        ),
      ],
      if (styleTab == 3) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              IconButton(
                isSelected: l.alignment == i,
                onPressed: enabled ? () => change(() => l.alignment = i) : null,
                icon: Icon(
                  [
                    Icons.format_align_left,
                    Icons.format_align_center,
                    Icons.format_align_right,
                  ][i],
                ),
              ),
          ],
        ),
        slider(
          'Line spacing',
          l.lineHeight,
          1,
          2.5,
          (v) => l.lineHeight = v,
          enabled: enabled,
        ),
        slider(
          'Rotation',
          l.rotation * 180 / math.pi,
          -180,
          180,
          (v) => l.rotation = v * math.pi / 180,
          enabled: enabled,
        ),
        TextButton.icon(
          onPressed: enabled ? () => change(() => l.x = 256) : null,
          icon: const Icon(Icons.align_horizontal_center),
          label: const Text('Center on canvas'),
        ),
      ],
      if (l.locked)
        const Text(
          'This layer is locked. Unlock it in Layers to edit.',
          style: TextStyle(color: Colors.black54),
        ),
    ];
  }

  List<Widget> backgroundTools() => [
    tabs(['Color', 'Gradient', 'Patterns', 'Images'], backgroundTab, (v) {
      setState(() => backgroundTab = v);
      panelUpdate?.call(() {});
    }),
    const SizedBox(height: 16),
    if (backgroundTab == 0) ...[
      swatches(background, (c) {
        background = c;
        backgroundMode = 0;
      }),
      const SizedBox(height: 10),
      const Text(
        'Checkerboard means transparent.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
    ],
    if (backgroundTab == 1) ...[
      const Text('Start color'),
      const SizedBox(height: 8),
      swatches(background, (c) {
        background = c;
        backgroundMode = 1;
      }, transparent: false),
      const SizedBox(height: 16),
      const Text('End color'),
      const SizedBox(height: 8),
      swatches(gradientEnd, (c) {
        gradientEnd = c;
        backgroundMode = 1;
      }, transparent: false),
    ],
    if (backgroundTab == 2) ...[
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (int p = 1; p <= 4; p++)
            InkWell(
              onTap: () => change(() {
                pattern = p;
                backgroundMode = 2;
                if (background == Colors.transparent) {
                  background = const Color(0xfffaf3e7);
                }
              }),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xfffaf3e7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: backgroundMode == 2 && pattern == p
                        ? AppColors.primary
                        : Colors.black12,
                  ),
                ),
                child: CustomPaint(
                  painter: StickerPatternPainter(p, gradientEnd),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Pattern color'),
      const SizedBox(height: 8),
      swatches(gradientEnd, (c) {
        gradientEnd = c;
        backgroundMode = 2;
      }, transparent: false),
    ],
    if (backgroundTab == 3) ...[
      OutlinedButton.icon(
        onPressed: importing ? null : () => importImage(asBackground: true),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(importing ? 'Preparing photo…' : 'Choose background image'),
      ),
      if (backgroundImage != null)
        TextButton(
          onPressed: () => change(() {
            backgroundImage = null;
            backgroundMode = 0;
          }),
          child: const Text('Remove background image'),
        ),
    ],
    const SizedBox(height: 22),
    const Text(
      'Stickers & Elements',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    ...elementTools(),
  ];
  List<Widget> elementTools() {
    const items = {
      '☕': 'Emojis',
      '💚': 'Emojis',
      '❤️': 'Emojis',
      '😎': 'Emojis',
      '😂': 'Emojis',
      '👑': 'Emojis',
      '💐': 'Emojis',
      '⭐': 'Emojis',
      '🎉': 'Emojis',
      '🏏': 'Cricket',
      '🏆': 'Cricket',
      '⚾': 'Cricket',
      '🇵🇰': 'Flags',
      '🌙': 'Flags',
    };
    return [
      tabs(
        ['All', 'Emojis', 'Shapes', 'Cricket', 'Flags'],
        [
          'All',
          'Emojis',
          'Shapes',
          'Cricket',
          'Flags',
        ].indexOf(elementCategory),
        (v) {
          setState(
            () => elementCategory = [
              'All',
              'Emojis',
              'Shapes',
              'Cricket',
              'Flags',
            ][v],
          );
          panelUpdate?.call(() {});
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (elementCategory == 'All')
            for (final asset in ['chai', 'mood-cat', 'cricket', 'eid'])
              InkWell(
                onTap: () => addElement('asset', 'assets/stickers/$asset.webp'),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Image.asset('assets/stickers/$asset.webp'),
                ),
              ),
          for (final e in items.entries)
            if (elementCategory == 'All' || elementCategory == e.value)
              InkWell(
                onTap: () => addElement('emoji', e.key),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xfffaf8f4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 30,
                      fontFamilyFallback: [
                        'Apple Color Emoji',
                        'Noto Color Emoji',
                      ],
                    ),
                  ),
                ),
              ),
          if (elementCategory == 'All' || elementCategory == 'Shapes')
            for (final shape in ['bubble', 'circle', 'star', 'badge', 'heart'])
              InkWell(
                onTap: () => addElement('shape', shape),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CustomPaint(
                    painter: ElementShapePainter(
                      shape,
                      const Color(0xffffbf3d),
                    ),
                  ),
                ),
              ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          final emoji = await askForEmoji(context);
          if (emoji != null && mounted) addElement('emoji', emoji);
        },
        icon: const Icon(Icons.emoji_emotions_outlined),
        label: const Text('Use any emoji'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: importing ? null : () => importImage(),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(importing ? 'Preparing image…' : 'Add image from gallery'),
      ),
      if (selected != null && selected!.kind != 'text') ...[
        slider(
          'Size',
          selected!.scale,
          .2,
          3,
          (v) => selected!.scale = v,
          enabled: !selected!.locked,
        ),
        slider(
          'Rotation',
          selected!.rotation * 180 / math.pi,
          -180,
          180,
          (v) => selected!.rotation = v * math.pi / 180,
          enabled: !selected!.locked,
        ),
        slider(
          'Opacity',
          selected!.opacity,
          0,
          1,
          (v) => selected!.opacity = v,
          enabled: !selected!.locked,
        ),
        if (selected!.kind == 'shape')
          swatches(Color(selected!.color), (c) {
            if (!selected!.locked) selected!.color = c.toARGB32();
          }, transparent: false),
      ],
    ];
  }

  Widget layerTools() => Column(
    children: [
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: layers.length,
        onReorderItem: (old, next) => change(() {
          final l = layers.removeAt(old);
          layers.insert(next, l);
        }),
        itemBuilder: (c, i) {
          final l = layers[i];
          return Card(
            key: ValueKey(l.id),
            color: selectedId == l.id
                ? const Color(0xffedf9f2)
                : const Color(0xfffafbfc),
            child: ListTile(
              onTap: () => select(l),
              leading: SizedBox(
                width: 42,
                height: 42,
                child: l.kind == 'text'
                    ? const Icon(Icons.text_fields)
                    : layerContent(l),
              ),
              title: Text(
                l.kind == 'text'
                    ? 'Text · ${l.content}'
                    : l.kind == 'asset'
                    ? l.content.split('/').last.split('.').first
                    : l.kind == 'image'
                    ? 'Image'
                    : l.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: l.locked
                  ? const Text('Locked', style: TextStyle(fontSize: 10))
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Toggle layer visibility',
                    onPressed: () => change(() => l.visible = !l.visible),
                    icon: Icon(
                      l.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          layerAction(
            'Duplicate',
            Icons.copy_outlined,
            selected == null ? null : duplicate,
          ),
          layerAction(
            'Delete',
            Icons.delete_outline,
            selected == null || selected!.locked ? null : removeSelected,
          ),
          layerAction(
            selected?.locked == true ? 'Unlock' : 'Lock',
            selected?.locked == true ? Icons.lock : Icons.lock_open,
            selected == null
                ? null
                : () => change(() => selected!.locked = !selected!.locked),
          ),
        ],
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton.icon(
            onPressed: addText,
            icon: const Icon(Icons.add),
            label: const Text('Add text'),
          ),
          TextButton.icon(
            onPressed: openElementsWithinPanel,
            icon: const Icon(Icons.add),
            label: const Text('Add sticker'),
          ),
        ],
      ),
      const Text(
        'Drag the handle to reorder. Bottom rows appear on top of the canvas.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
  Widget layerAction(String label, IconData icon, VoidCallback? action) =>
      Expanded(
        child: TextButton(
          onPressed: action,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
  void openElementsWithinPanel() {
    setState(() => tool = 1);
    panelUpdate?.call(() {});
  }

  Future<void> openTool(int value) async {
    tool = value;
    if (value == 0 && selected?.kind != 'text') {
      final existing = layers.where((l) => l.kind == 'text').firstOrNull;
      if (existing != null) {
        select(existing);
      } else {
        addText();
      }
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          panelUpdate = update;
          return FractionallySizedBox(
            heightFactor: .94,
            child: Column(
              children: [
                ListTile(
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  title: Text(
                    [
                      'Text Style',
                      'Stickers & Elements',
                      'Backgrounds',
                      'Layers',
                    ][tool],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Done',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      if (tool != 3) ...[
                        SizedBox(
                          height: 210,
                          child: CustomPaint(
                            painter: StickerCheckerPainter(),
                            child: composition(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (tool == 0) ...textTools(),
                      if (tool == 1) ...elementTools(),
                      if (tool == 2) ...backgroundTools(),
                      if (tool == 3) layerTools(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    panelUpdate = null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sticker Editor', style: TextStyle(fontSize: 16)),
      actions: [
        IconButton(
          tooltip: 'Undo',
          onPressed: cursor > 0 ? () => restore(cursor - 1) : null,
          icon: const Icon(Icons.undo, size: 21),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: cursor < history.length - 1
              ? () => restore(cursor + 1)
              : null,
          icon: const Icon(Icons.redo, size: 21),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: FilledButton(
            onPressed: exporting
                ? null
                : () async {
                    await save();
                    if (mounted) await export();
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(exporting ? '…' : 'Save'),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Make it yours',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${layers.length} layers',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff123f31)
                                .withValues(alpha: .08),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: StickerCheckerPainter(),
                          child: composition(interactive: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 22, bottom: 10),
              child: Text(
                'Drag to move · Pinch to resize',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffebeae3))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StiksyAd(),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final e in [
                  Icons.text_fields,
                  Icons.emoji_emotions_outlined,
                  Icons.texture,
                  Icons.layers_outlined,
                ].asMap().entries)
                  Expanded(
                    child: InkWell(
                      onTap: () => openTool(e.key),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(e.value, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            ['Text', 'Stickers', 'Background', 'Layers'][e.key],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SelectionBorderPainter extends CustomPainter {
  const SelectionBorderPainter(this.locked);
  final bool locked;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = locked ? Colors.grey : AppColors.primary
      ..strokeWidth = 2;
    for (double x = 0; x < s.width; x += 12) {
      c.drawLine(Offset(x, 0), Offset(math.min(x + 7, s.width), 0), p);
      c.drawLine(
        Offset(x, s.height),
        Offset(math.min(x + 7, s.width), s.height),
        p,
      );
    }
    for (double y = 0; y < s.height; y += 12) {
      c.drawLine(Offset(0, y), Offset(0, math.min(y + 7, s.height)), p);
      c.drawLine(
        Offset(s.width, y),
        Offset(s.width, math.min(y + 7, s.height)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionBorderPainter old) => old.locked != locked;
}

class ElementShapePainter extends CustomPainter {
  const ElementShapePainter(this.kind, this.color);
  final String kind;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = color;
    final rect = Rect.fromLTWH(5, 5, s.width - 10, s.height - 10);
    if (kind == 'heart') {
      final path = Path()
        ..moveTo(s.width * .5, s.height * .9)
        ..cubicTo(
          -s.width * .12,
          s.height * .45,
          s.width * .08,
          -s.height * .15,
          s.width * .5,
          s.height * .25,
        )
        ..cubicTo(
          s.width * .92,
          -s.height * .15,
          s.width * 1.12,
          s.height * .45,
          s.width * .5,
          s.height * .9,
        )
        ..close();
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white,
      );
      c.drawPath(path, paint);
      return;
    }
    if (kind == 'circle') {
      c.drawOval(rect, paint);
      return;
    }
    if (kind == 'bubble') {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 5, s.width - 10, s.height * .72),
          Radius.circular(s.width * .14),
        ),
        paint,
      );
      c.drawPath(
        Path()
          ..moveTo(s.width * .2, s.height * .6)
          ..lineTo(s.width * .2, s.height * .95)
          ..lineTo(s.width * .45, s.height * .65)
          ..close(),
        paint,
      );
      return;
    }
    final points = kind == 'star' ? 5 : 10;
    final path = Path();
    final center = s.center(Offset.zero);
    for (int i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final radius =
          math.min(s.width, s.height) *
          (i.isEven
              ? 0.46
              : kind == 'star'
              ? 0.22
              : 0.38);
      final x = center.dx + math.cos(a) * radius,
          y = center.dy + math.sin(a) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ElementShapePainter old) =>
      old.kind != kind || old.color != color;
}
