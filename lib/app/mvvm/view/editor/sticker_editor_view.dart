import '../../../config/app_radius.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../custom_widgets/art_image.dart';
import '../../../services/draft_images.dart';
import '../../../services/remote_content.dart';
import '../../../services/haptic_service.dart';
import '../../../services/template_access.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/sticker_components.dart';
import '../../../custom_widgets/sticker_background.dart';
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
  double rawX = 0, rawY = 0;
  bool snapX = false, snapY = false, snapRotation = false;
  bool importing = false, exporting = false;
  bool showTip = false;
  bool typing = false;
  Uint8List? _bgBytes;
  String? _bgSource;

  Uint8List get _backgroundBytes {
    final source = backgroundImage!;
    if (_bgBytes == null || _bgSource != source) {
      _bgBytes = base64Decode(source);
      _bgSource = source;
    }
    return _bgBytes!;
  }

  static const _tipKey = 'stiksy_editor_tip_seen';

  void dismissTip() {
    if (!showTip) return;
    setState(() => showTip = false);
    Get.find<SharedPreferences>().setBool(_tipKey, true);
  }

  Widget _tipBanner() => Container(
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(
      color: const Color(0xffe8f5ee).withValues(alpha: .96),
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.borderColor),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.touch_app_outlined,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Drag to move · Pinch to resize · Double-tap text to type',
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextButton(onPressed: dismissTip, child: const Text('Got it')),
      ],
    ),
  );

  Widget _blankPrompt() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Start your sticker',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  addText();
                  final l = selected;
                  if (l != null) editText(l);
                },
                icon: const Icon(Icons.text_fields_rounded),
                label: const Text('Add text'),
              ),
              FilledButton.tonalIcon(
                onPressed: importImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photo'),
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final emoji = await askForEmoji(context);
                  if (emoji != null && mounted) addElement('emoji', emoji);
                },
                icon: const Icon(Icons.emoji_emotions_outlined),
                label: const Text('Add emoji'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
    showTip = !(Get.find<SharedPreferences>().getBool(_tipKey) ?? false);
    if (widget.initialDesign != null) {
      apply(widget.initialDesign!);
      draftId = widget.initialDesign!['draftId'];
    } else {
      // The chai picture has no words of its own, so like an emoji it gets
      // the template text above it. The layout matches the template preview,
      // so the user edits exactly the design they picked.
      final embedded =
          widget.template.asset != null &&
          widget.template.asset != 'assets/stickers/chai.webp';
      if (!embedded) {
        layers.add(
          EditorLayer(
            id: 'text-0',
            kind: 'text',
            content: widget.template.text,
            x: 256,
            y: 166,
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
          x: 256,
          y: embedded ? 256 : 338,
          width: embedded ? 410 : 260,
          height: embedded ? 410 : 260,
        ),
      );
      selectedId = layers.last.id;
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

  int get maxDrafts => RemoteContent.settings.value.maxDrafts;

  int savedCursor = 0;
  bool get dirty => cursor != savedCursor;
  bool leaving = false;

  Future<bool> confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save your design?'),
        content: const Text('You have changes that haven’t been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'stay'),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await save();
      return true;
    }
    return choice == 'discard';
  }

  static dynamic _clone(dynamic v) => v is Map
      ? {for (final e in v.entries) '${e.key}': _clone(e.value)}
      : v is List
      ? [for (final e in v) _clone(e)]
      : v;

  void record({bool replace = false}) {
    if (replace && cursor == history.length - 1 && history.length > 1) {
      history[cursor] = _clone(snapshot()) as Map<String, dynamic>;
      return;
    }
    history.removeRange(cursor + 1, history.length);
    history.add(_clone(snapshot()) as Map<String, dynamic>);
    if (history.length > 80) {
      history.removeAt(0);
      savedCursor--;
    }
    cursor = history.length - 1;
  }

  String? lastGroup;
  DateTime lastGroupAt = DateTime.fromMillisecondsSinceEpoch(0);

  void change(VoidCallback action, {String? group}) {
    final now = DateTime.now();
    final merge =
        group != null &&
        group == lastGroup &&
        now.difference(lastGroupAt) < const Duration(seconds: 1);
    setState(() {
      action();
      record(replace: merge);
    });
    lastGroup = group;
    lastGroupAt = now;
    panelUpdate?.call(() {});
    if (showTip) dismissTip();
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), () {
      if (mounted && dirty) save(silent: true);
    });
  }

  void select(EditorLayer layer) {
    setState(() {
      selectedId = layer.id;
      syncText();
    });
    panelUpdate?.call(() {});
  }

  void restore(int index) {
    lastGroup = null;
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

  final Map<int, Offset> _pointers = {};
  final ValueNotifier<int> _canvasTick = ValueNotifier(0);
  final Map<int, String> _pointerOwner = {};
  double _pinchStartDistance = 1, _lastAngle = 0, _rotationSum = 0;
  Offset _lastFocal = Offset.zero;
  bool _dragged = false;

  Offset _focal(Iterable<Offset> points) =>
      points.fold(Offset.zero, (a, b) => a + b) / points.length.toDouble();

  void _rebaseline(EditorLayer l) {
    startScale = l.scale;
    startRotation = l.rotation;
    rawX = l.x;
    rawY = l.y;
    final points = _pointers.values.toList();
    _lastFocal = _focal(points);
    _rotationSum = 0;
    if (points.length >= 2) {
      final span = points[1] - points[0];
      _pinchStartDistance = math.max(span.distance, 1);
      _lastAngle = span.direction;
    }
  }

  void _pointerDown(EditorLayer l, PointerDownEvent e) {
    if (l.locked || _pointerOwner.containsKey(e.pointer)) return;

    if (_pointerOwner.isEmpty) {
      _pointers.clear();
      _dragged = false;
    }
    _pointerOwner[e.pointer] = l.id;
    _pointers[e.pointer] = e.position;
    _rebaseline(l);
  }

  void _pointerMove(EditorLayer l, PointerMoveEvent e) {
    if (_pointerOwner[e.pointer] != l.id) return;
    _pointers[e.pointer] = e.position;
    final points = _pointers.values.toList();
    final focal = _focal(points);
    final delta = focal - _lastFocal;
    _lastFocal = focal;
    var scale = 1.0, rotation = 0.0;
    if (points.length >= 2) {
      final span = points[1] - points[0];
      scale = span.distance / _pinchStartDistance;
      var step = span.direction - _lastAngle;
      if (step > math.pi) step -= 2 * math.pi;
      if (step < -math.pi) step += 2 * math.pi;
      _rotationSum += step;
      _lastAngle = span.direction;
      rotation = _rotationSum;
    }
    if (!_dragged && delta == Offset.zero && scale == 1 && rotation == 0) {
      return;
    }
    if (!_dragged) {
      _dragged = true;
      if (selectedId != l.id) select(l);
    }
    dragLayer(l, delta, scale, rotation);
  }

  EditorLayer? _ownerLayer(int pointer) =>
      layers.where((x) => x.id == _pointerOwner[pointer]).firstOrNull;

  void _canvasMove(PointerMoveEvent e) {
    final l = _ownerLayer(e.pointer);
    if (l != null) _pointerMove(l, e);
  }

  void _canvasEnd(PointerEvent e) {
    final l = _ownerLayer(e.pointer);
    if (l != null) {
      _pointerEnd(l, e);
    } else if (_pointerOwner[e.pointer]?.contains(':') ?? false) {
      // A handle that never saw its own release.
      _pointerOwner.remove(e.pointer);
      _handleOrigin.remove(e.pointer);
    }
  }

  void _pointerEnd(EditorLayer l, PointerEvent e) {
    if (_pointerOwner[e.pointer] != l.id) return;
    _pointerOwner.remove(e.pointer);
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) {
      _rebaseline(l); // One finger lifted: carry on with the other.
      return;
    }
    snapX = snapY = snapRotation = false;
    if (_dragged) {
      _dragged = false;
      change(() {});
    } else if (mounted) {
      setState(() {}); // Clear any guide lines.
    }
  }

  final Map<String, Size> _extentCache = {};

  Size _textExtent(EditorLayer l) {
    final key =
        '${l.content}|${l.font}|${l.fontSize}|${l.width}|${l.lineHeight}|${l.alignment}';
    final cached = _extentCache[key];
    if (cached != null) return cached;
    if (_extentCache.length > 64) _extentCache.clear();
    return _extentCache[key] = _measureText(l);
  }

  Size _measureText(EditorLayer l) {
    final painter = TextPainter(
      text: TextSpan(
        text: l.content.isEmpty ? ' ' : l.content,
        style: TextStyle(
          fontFamily: l.font.isEmpty ? null : l.font,
          fontSize: l.fontSize,
          fontWeight: FontWeight.w700,
          height: l.lineHeight,
        ),
      ),
      textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(l.content)
          ? TextDirection.rtl
          : TextDirection.ltr,
      textAlign: l.textAlign,
    )..layout(maxWidth: l.width);
    final size = Size(painter.width, painter.height);
    painter.dispose();
    return size;
  }

  Rect _touchRect(EditorLayer l) {
    final box = Offset.zero & Size(l.width * l.scale, l.height * l.scale);
    if (l.kind != 'text') return box;
    final words = _textExtent(l);
    final fit = math.min(
      1.0,
      math.min(l.width / words.width, l.height / words.height),
    );
    final pad = 10.0 * l.scale;
    final minSide = 56 / displayScale; // never smaller than a fingertip
    final w = math.max(words.width * fit * l.scale + 2 * pad, minSide);
    final h = math.max(words.height * fit * l.scale + 2 * pad, minSide);
    return Rect.fromCenter(
      center: box.center,
      width: math.min(box.width, w),
      height: math.min(box.height, h),
    );
  }

  Widget _interactiveLayer(EditorLayer l) => Stack(
    clipBehavior: Clip.none,
    children: [Positioned.fromRect(rect: _touchRect(l), child: _touchArea(l))],
  );

  Widget _touchArea(EditorLayer l) {
    final selectedHere = selectedId == l.id;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _pointerDown(l, e),
            child: GestureDetector(
              key: ValueKey('canvas-layer-${l.id}'),
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) => select(l),
              onDoubleTap: l.kind == 'text' ? () => editText(l) : null,
              child: selectedHere
                  ? CustomPaint(painter: SelectionBorderPainter(l.locked))
                  : const SizedBox.expand(),
            ),
          ),
        ),
        if (selectedHere) ...[
          Positioned(
            left: -24 / displayScale,
            top: -24 / displayScale,
            child: handle(
              Icons.delete_outline,
              const Color(0xffff4b85),
              l.locked ? null : removeSelected,
              'Delete selected layer',
              owner: 'delete:${l.id}',
            ),
          ),
          Positioned(
            right: -24 / displayScale,
            top: -24 / displayScale,
            child: handle(
              l.locked ? Icons.lock : Icons.copy,
              AppColors.primary,
              duplicate,
              'Duplicate selected layer',
              owner: 'duplicate:${l.id}',
            ),
          ),
          Positioned(
            right: -24 / displayScale,
            bottom: -24 / displayScale,
            child: handle(
              Icons.open_in_full,
              AppColors.primary,
              null,
              'Resize layer',
              owner: 'resize:${l.id}',
              onDrag: l.locked
                  ? (_) {}
                  : (dx) {
                      l.scale = (l.scale + dx / (l.width * displayScale)).clamp(
                        .2,
                        3,
                      );
                      _canvasTick.value++;
                    },
              onDragEnd: () {
                if (!l.locked) change(() {});
              },
            ),
          ),
        ],
      ],
    );
  }

  static const _snapDistance = 7.0; // canvas px (of 512)
  static const _snapAngle = .05; // radians, about 3 degrees

  void dragLayer(EditorLayer l, Offset delta, double scale, double rotation) {
    rawX = (rawX + delta.dx / displayScale).clamp(0, 512);
    rawY = (rawY + delta.dy / displayScale).clamp(0, 512);
    final nearX = (rawX - 256).abs() < _snapDistance;
    final nearY = (rawY - 256).abs() < _snapDistance;
    final raw = startRotation + rotation;
    final quarter = math.pi / 2;
    final nearest = (raw / quarter).roundToDouble() * quarter;
    // Only snap rotation once the user is actually twisting.
    final nearAngle = rotation != 0 && (raw - nearest).abs() < _snapAngle;
    if ((nearX && !snapX) ||
        (nearY && !snapY) ||
        (nearAngle && !snapRotation)) {
      HapticService.light();
    }
    snapX = nearX;
    snapY = nearY;
    snapRotation = nearAngle;
    l.x = nearX ? 256 : rawX;
    l.y = nearY ? 256 : rawY;
    l.scale = (startScale * scale).clamp(.2, 3);
    l.rotation = nearAngle ? nearest : raw;
    _canvasTick.value++;
  }

  List<TextPreset> get _presets => RemoteContent.settings.value.presets;

  bool _matches(EditorLayer l, TextPreset p) =>
      l.color == p.color &&
      l.outline == p.outline &&
      l.shadow == p.shadow &&
      (!p.outline || l.outlineWidth == p.outlineWidth);

  Future<void> showStyles(EditorLayer l) async {
    if (l.locked) return;
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.white,
      elevation: 12,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pick a look',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Done',
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
                SizedBox(
                  height: 84,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final p in _presets)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            borderRadius: AppRadius.mdAll,
                            onTap: () {
                              change(() {
                                l.color = p.color;
                                l.outline = p.outline;
                                l.outlineWidth = p.outlineWidth;
                                l.shadow = p.shadow;
                                l.shadowBlur = p.shadowBlur;
                              });
                              setSheet(() {});
                            },
                            child: Container(
                              width: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xffeef2ef),
                                borderRadius: AppRadius.mdAll,
                                border: Border.all(
                                  color: _matches(l, p)
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (p.outline)
                                        Text(
                                          'Aa',
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = p.outlineWidth / 2
                                              ..color = Colors.white,
                                          ),
                                        ),
                                      Text(
                                        'Aa',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: Color(p.color),
                                          shadows: p.shadow
                                              ? const [
                                                  Shadow(
                                                    color: Colors.black45,
                                                    blurRadius: 4,
                                                    offset: Offset(1, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void deselect() {
    if (selectedId == null) return;
    setState(() {
      selectedId = null;
      syncText();
    });
    panelUpdate?.call(() {});
  }

  Future<void> editText(EditorLayer l) async {
    if (l.locked) {
      notify('Unlock this text to edit it.');
      return;
    }
    select(l);
    setState(() => typing = true);
    final input = TextEditingController(text: l.content);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.white,
      elevation: 12,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 160,
                    textInputAction: TextInputAction.newline,
                    onChanged: (v) =>
                        change(() => l.content = v, group: 'text:${l.id}'),
                    decoration: const InputDecoration(
                      hintText: 'Urdu, English or Roman Urdu…',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Done',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), input.dispose);
    if (mounted) setState(() => typing = false);
    // A text layer left empty would be invisible clutter.
    if (mounted && l.content.trim().isEmpty && layers.contains(l)) {
      change(() {
        layers.remove(l);
        selectedId = layers.lastOrNull?.id;
        syncText();
      });
    } else {
      syncText();
    }
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

  Future<void> _saveQueue = Future.value();
  Timer? _autosave;
  Future<void> save({bool silent = false}) {
    final run = _saveQueue.then((_) => _save(silent));
    _saveQueue = run.catchError((_) {});
    return run;
  }

  Future<void> _save(bool silent) async {
    final prefs = Get.find<SharedPreferences>();
    final drafts = prefs.getStringList('stiksy_drafts') ?? [];
    draftId ??= identifier();
    final raw = jsonEncode({
      ...await DraftImages.externalize(snapshot()),
      'draftId': draftId,
      'template': widget.template.id,
      'savedAt': DateTime.now().toIso8601String(),
    });
    final index = drafts.indexWhere((v) => jsonDecode(v)['draftId'] == draftId);
    if (index < 0) {
      drafts.add(raw);
      if (drafts.length > maxDrafts) {
        drafts.removeRange(0, drafts.length - maxDrafts);
      }
    } else {
      drafts[index] = raw;
    }
    await prefs.setStringList('stiksy_drafts', drafts);
    savedCursor = cursor;
    // Rebuild so the back-button guard sees there is nothing left unsaved.
    if (mounted) setState(() {});
    lastGroup = null; // Edits after a save never fold into the saved step.
    await DraftImages.collect(drafts);
    if (!silent && mounted) 'Design saved on this device.'.showSuccess();
  }

  void notify(String message) {
    if (mounted) {
      message.showInfo();
    }
  }

  void notifyError(String message) {
    if (mounted) {
      message.showError();
    }
  }

  @override
  void dispose() {
    _canvasTick.dispose();
    _autosave?.cancel();
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: l.width,
              child: Stack(
                alignment: Alignment.center,
                children: [if (l.outline) words(l, stroke: true), words(l)],
              ),
            ),
          ),
        );
      case 'asset':
        return artImage(l.content);
      case 'image':
        return Image.memory(
          l.imageBytes,
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
    key: ValueKey('layer-position-${l.id}'),
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
          Image.memory(_backgroundBytes, fit: BoxFit.cover),
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
                    Positioned.fill(
                      key: const ValueKey('snap-guides'),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: SnapGuidePainter(
                            vertical: snapX,
                            horizontal: snapY,
                          ),
                        ),
                      ),
                    ),
                  if (interactive)
                    Positioned.fill(
                      key: const ValueKey('canvas-empty-area'),
                      child: GestureDetector(
                        key: const ValueKey('canvas-empty'),
                        behavior: HitTestBehavior.opaque,
                        onTap: deselect,
                      ),
                    ),
                  if (interactive)
                    for (final l in layers)
                      if (l.visible) position(l, _interactiveLayer(l)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  final Map<int, Offset> _handleOrigin = {};

  Widget handle(
    IconData icon,
    Color color,
    VoidCallback? action,
    String label, {
    required String owner,
    void Function(double dx)? onDrag,
    VoidCallback? onDragEnd,
  }) {
    final k = 1 / displayScale.clamp(.3, 3);
    return Semantics(
      label: label,
      button: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointerOwner.containsKey(e.pointer)) return;
          _pointerOwner[e.pointer] = owner;
          _handleOrigin[e.pointer] = e.position;
        },
        onPointerMove: (e) {
          if (_pointerOwner[e.pointer] == owner) onDrag?.call(e.delta.dx);
        },
        onPointerUp: (e) {
          if (_pointerOwner[e.pointer] != owner) return;
          _pointerOwner.remove(e.pointer);
          final origin = _handleOrigin.remove(e.pointer) ?? e.position;
          if (onDrag != null) {
            onDragEnd?.call();
          } else if ((e.position - origin).distance < 14) {
            action?.call(); // A tap, not a drag that ended on the handle.
          }
        },
        onPointerCancel: (e) {
          if (_pointerOwner[e.pointer] != owner) return;
          _pointerOwner.remove(e.pointer);
          _handleOrigin.remove(e.pointer);
        },
        child: SizedBox(
          width: 48 * k,
          height: 48 * k,
          child: Center(
            child: Container(
              width: 34 * k,
              height: 34 * k,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2 * k),
              ),
              child: Icon(icon, color: Colors.white, size: 18 * k),
            ),
          ),
        ),
      ),
    );
  }

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
            template: widget.template,
            bytes: data.buffer.asUint8List(),
            text: layers
                .where((l) => l.kind == 'text' && l.visible)
                .map((l) => l.content)
                .join('\n'),
          ),
        );
      }
    } catch (_) {
      notifyError('Couldn’t make this sticker. Please try again.');
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
      notifyError('Couldn’t open this photo. Please choose another one.');
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
                borderRadius: AppRadius.smAll,
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
          onChanged: enabled
              ? (v) => change(() => pick(v), group: 'slider:$label:$selectedId')
              : null,
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
              onChanged: (v) =>
                  change(() => l.content = v, group: 'text:${l.id}'),
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
                              borderRadius: AppRadius.smAll,
                              border: Border.all(
                                color: l.font == f.key
                                    ? AppColors.primary
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
                                          ? AppColors.primary
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
                  borderRadius: AppRadius.smAll,
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
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 10),
    ...elementTools(),
  ];
  List<Widget> elementTools() {
    final sets = RemoteContent.settings.value.elements;
    final items = [
      for (final set in sets)
        for (final emoji in set.emojis) MapEntry(emoji, set.category),
    ];
    // Emoji tabs come from the admin panel; "Shapes" is built in.
    final tabNames = ['All', ...sets.map((e) => e.category), 'Shapes'];
    if (!tabNames.contains(elementCategory)) elementCategory = 'All';
    return [
      tabs(tabNames, tabNames.indexOf(elementCategory), (v) {
        setState(() => elementCategory = tabNames[v]);
        panelUpdate?.call(() {});
      }),
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
          for (final e in items)
            if (elementCategory == 'All' || elementCategory == e.value)
              InkWell(
                onTap: () => addElement('emoji', e.key),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xfff2f4f3),
                    borderRadius: AppRadius.smAll,
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
    if (value != 0) return openPanel(value);
    var target = selected?.kind == 'text'
        ? selected
        : layers.where((l) => l.kind == 'text').lastOrNull;
    if (target == null) {
      addText();
      target = selected;
    }
    if (target != null) await editText(target);
  }

  Future<void> openPanel(int value) async {
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
                      'Arrange',
                    ][tool],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

  static const _quickColors = [
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

  Widget _stripButton(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool active = false,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    isSelected: active,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 22),
    style: active
        ? IconButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: .14),
          )
        : null,
  );

  Widget _row(List<Widget> items) => Row(
    children: [
      for (final item in items)
        Expanded(
          child: FittedBox(fit: BoxFit.scaleDown, child: item),
        ),
    ],
  );

  Widget contextStrip() {
    final l = selected;
    if (l == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Tap an item to edit it · Double-tap text to type',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      );
    }
    final unlocked = !l.locked;
    if (l.kind != 'text') {
      return _row([
        _stripButton(
          Icons.zoom_out,
          'Make smaller',
          unlocked
              ? () => change(
                  () => l.scale = (l.scale - .15).clamp(.2, 3),
                  group: 'scale:${l.id}',
                )
              : null,
        ),
        _stripButton(
          Icons.zoom_in,
          'Make bigger',
          unlocked
              ? () => change(
                  () => l.scale = (l.scale + .15).clamp(.2, 3),
                  group: 'scale:${l.id}',
                )
              : null,
        ),
        _stripButton(Icons.copy_outlined, 'Duplicate item', duplicate),
        _stripButton(
          Icons.delete_outline,
          'Delete item',
          unlocked ? removeSelected : null,
        ),
        _stripButton(
          l.locked ? Icons.lock : Icons.lock_open,
          l.locked ? 'Unlock item' : 'Lock item',
          () => change(() => l.locked = !l.locked),
          active: l.locked,
        ),
        _stripButton(Icons.tune, 'More options', () => openPanel(3)),
      ]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row([
          _stripButton(
            Icons.edit_outlined,
            'Edit words',
            unlocked ? () => editText(l) : null,
          ),
          _stripButton(
            Icons.auto_awesome_outlined,
            'Style presets',
            unlocked ? () => showStyles(l) : null,
          ),
          PopupMenuButton<String>(
            tooltip: 'Font',
            enabled: unlocked,
            onSelected: (f) => change(() => l.font = f),
            itemBuilder: (_) => [
              for (final f in fonts.entries)
                PopupMenuItem(
                  value: f.key,
                  child: Text(
                    f.value,
                    style: TextStyle(
                      fontFamily: f.key.isEmpty ? null : f.key,
                      fontSize: 18,
                    ),
                  ),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.font_download_outlined, size: 22),
            ),
          ),
          _stripButton(
            Icons.text_decrease,
            'Smaller text',
            unlocked
                ? () => change(
                    () => l.fontSize = (l.fontSize - 4).clamp(16, 90),
                    group: 'size:${l.id}',
                  )
                : null,
          ),
          _stripButton(
            Icons.text_increase,
            'Bigger text',
            unlocked
                ? () => change(
                    () => l.fontSize = (l.fontSize + 4).clamp(16, 90),
                    group: 'size:${l.id}',
                  )
                : null,
          ),
          _stripButton(
            [
              Icons.format_align_left,
              Icons.format_align_center,
              Icons.format_align_right,
            ][l.alignment.clamp(0, 2)],
            'Text alignment',
            unlocked
                ? () => change(() => l.alignment = (l.alignment + 1) % 3)
                : null,
          ),
          _stripButton(
            Icons.border_style,
            'Outline',
            unlocked ? () => change(() => l.outline = !l.outline) : null,
            active: l.outline,
          ),
          _stripButton(Icons.tune, 'More options', () => openPanel(0)),
        ]),
        const SizedBox(height: 2),
        _row([
          for (final c in _quickColors)
            InkResponse(
              radius: 22,
              onTap: unlocked
                  ? () => change(() => l.color = c.toARGB32())
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: l.color == c.toARGB32()
                          ? AppColors.primary
                          : Colors.black26,
                      width: l.color == c.toARGB32() ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty || leaving,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final ok = await confirmLeave();
      if (!mounted || !ok) return;
      final navigator = Navigator.of(this.context);
      setState(() => leaving = true);
      // Pop once the rebuilt PopScope allows it, so it doesn't ask again.
      WidgetsBinding.instance.addPostFrameCallback((_) => navigator.pop());
    },
    child: _scaffold(context),
  );

  Widget _scaffold(BuildContext context) => Scaffold(
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
                    // Premium templates are free to edit; the video is asked
                    // for only now, when the user is about to take the result.
                    if (!mounted) return;
                    if (!await TemplateAccess.allow(
                      this.context,
                      widget.template,
                    )) {
                      return;
                    }
                    if (mounted) await export();
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
            ),
            child: Text(exporting ? '…' : 'Finish'),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.mdAll,
                        child: CustomPaint(
                          painter: StickerCheckerPainter(),
                          child: Stack(
                            children: [
                              Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerMove: _canvasMove,
                                onPointerUp: _canvasEnd,
                                onPointerCancel: _canvasEnd,
                                child: ListenableBuilder(
                                  listenable: _canvasTick,
                                  builder: (_, _) =>
                                      composition(interactive: true),
                                ),
                              ),
                              if (layers.isEmpty) _blankPrompt(),
                              if (showTip)
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  top: 8,
                                  child: _tipBanner(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (typing)
              // Room for the typing bar that floats above the keyboard.
              const SizedBox(height: 84)
            else
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: contextStrip(),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe5e9e6))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                            [
                              'Text',
                              'Stickers',
                              'Background',
                              'Arrange',
                            ][e.key],
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

class SnapGuidePainter extends CustomPainter {
  const SnapGuidePainter({required this.vertical, required this.horizontal});
  final bool vertical, horizontal;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5;
    if (vertical) {
      for (double y = 0; y < s.height; y += 10) {
        c.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, y + 5), p);
      }
    }
    if (horizontal) {
      for (double x = 0; x < s.width; x += 10) {
        c.drawLine(Offset(x, s.height / 2), Offset(x + 5, s.height / 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(SnapGuidePainter old) =>
      old.vertical != vertical || old.horizontal != horizontal;
}
