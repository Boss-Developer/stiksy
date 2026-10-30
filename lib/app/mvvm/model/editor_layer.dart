import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class EditorLayer {
  EditorLayer({
    required this.id,
    required this.kind,
    required this.content,
    this.x = 256,
    this.y = 256,
    this.width = 320,
    this.height = 220,
    this.scale = 1,
    this.rotation = 0,
    this.font = 'NotoNastaliqUrdu',
    this.fontSize = 40,
    this.color = 0xff302317,
    this.opacity = 1,
    this.outline = true,
    this.outlineWidth = 5,
    this.shadow = false,
    this.shadowBlur = 5,
    this.lineHeight = 1.5,
    this.alignment = 1,
    this.visible = true,
    this.locked = false,
  });
  String id, kind, content, font;
  double x, y, width, height, scale, rotation, fontSize, opacity;
  double outlineWidth, shadowBlur, lineHeight;
  int color, alignment;
  bool outline, shadow, visible, locked;
  Uint8List? _bytes;
  String? _bytesSource;

  Uint8List get imageBytes {
    if (_bytes != null && !identical(_bytesSource, content)) {
      if (_bytesSource == content) {
        _bytesSource = content;
      } else {
        _bytes = null;
      }
    }
    if (_bytes == null) {
      _bytes = base64Decode(content);
      _bytesSource = content;
    }
    return _bytes!;
  }

  TextAlign get textAlign => [
    TextAlign.left,
    TextAlign.center,
    TextAlign.right,
  ][alignment.clamp(0, 2)];
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'content': content,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scale': scale,
    'rotation': rotation,
    'font': font,
    'fontSize': fontSize,
    'color': color,
    'opacity': opacity,
    'outline': outline,
    'outlineWidth': outlineWidth,
    'shadow': shadow,
    'shadowBlur': shadowBlur,
    'lineHeight': lineHeight,
    'alignment': alignment,
    'visible': visible,
    'locked': locked,
  };
  factory EditorLayer.fromJson(Map<String, dynamic> v) {
    double n(String key, double fallback) =>
        (v[key] as num?)?.toDouble() ?? fallback;
    return EditorLayer(
      id: '${v['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      kind: '${v['kind'] ?? 'text'}',
      content: '${v['content'] ?? ''}',
      x: n('x', 256),
      y: n('y', 256),
      width: n('width', 320),
      height: n('height', 220),
      scale: n('scale', 1),
      rotation: n('rotation', 0),
      font: v['font'] ?? 'NotoNastaliqUrdu',
      fontSize: n('fontSize', 40),
      color: v['color'] ?? 0xff302317,
      opacity: n('opacity', 1),
      outline: v['outline'] ?? true,
      outlineWidth: n('outlineWidth', 5),
      shadow: v['shadow'] ?? false,
      shadowBlur: n('shadowBlur', 5),
      lineHeight: n('lineHeight', 1.5),
      alignment: v['alignment'] ?? 1,
      visible: v['visible'] ?? true,
      locked: v['locked'] ?? false,
    );
  }
}
