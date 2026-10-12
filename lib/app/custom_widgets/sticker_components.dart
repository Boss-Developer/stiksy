import 'package:flutter/material.dart';

import '../mvvm/model/sticker_template.dart';
import 'stiksy_crown.dart';

class StickerArtwork extends StatelessWidget {
  const StickerArtwork({
    super.key,
    required this.template,
    this.showBackground = true,
  });
  final StickerTemplate template;
  final bool showBackground;
  @override
  Widget build(BuildContext context) {
    final isUrdu = RegExp(r'[\u0600-\u06ff]').hasMatch(template.text);
    final embedded =
        template.asset != null && template.asset != 'assets/stickers/chai.webp';
    Widget title({bool stroke = false}) => Text(
      template.text,
      textAlign: TextAlign.center,
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null,
        fontSize: isUrdu ? 28 : 24,
        height: isUrdu ? 1.8 : 1.2,
        fontWeight: FontWeight.w900,
        color: stroke ? null : const Color(0xff302317),
        foreground: stroke
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = Colors.white)
            : null,
      ),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: showBackground ? const Color(0xfff0f3f1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: embedded
            ? Image.asset(template.asset!, fit: BoxFit.contain)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [title(stroke: true), title()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    flex: 4,
                    child: template.asset != null
                        ? Image.asset(template.asset!, fit: BoxFit.contain)
                        : FittedBox(
                            child: Text(
                              template.emoji,
                              style: const TextStyle(
                                fontSize: 64,
                                fontFamilyFallback: [
                                  'Apple Color Emoji',
                                  'Noto Color Emoji',
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });
  final StickerTemplate template;
  final bool favorite;
  final VoidCallback onTap, onFavorite;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Semantics(
          label: template.title,
          button: true,
          child: InkWell(
            onTap: onTap,
            onLongPress: onFavorite,
            borderRadius: BorderRadius.circular(14),
            child: StickerArtwork(template: template),
          ),
        ),
      ),
      if (template.premium)
        const Positioned(right: 7, top: 5, child: StiksyCrown(size: 22)),
      Positioned(
        right: 0,
        bottom: 0,
        child: IconButton(
          tooltip: favorite ? 'Remove favorite' : 'Add favorite',
          onPressed: onFavorite,
          icon: Icon(
            favorite ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: favorite ? const Color(0xffff4b75) : Colors.black38,
          ),
        ),
      ),
    ],
  );
}

class TemplateGrid extends StatelessWidget {
  const TemplateGrid({
    super.key,
    required this.templates,
    required this.favorites,
    required this.onTap,
    required this.onFavorite,
  });
  final List<StickerTemplate> templates;
  final List<String> favorites;
  final void Function(StickerTemplate) onTap, onFavorite;
  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No templates found. Try another search or category.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: templates.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 650 ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
          mainAxisExtent: constraints.maxWidth >= 650
              ? 210
              : (constraints.maxWidth - 16) / 2,
        ),
        itemBuilder: (_, i) => TemplateCard(
          template: templates[i],
          favorite: favorites.contains(templates[i].id),
          onTap: () => onTap(templates[i]),
          onFavorite: () => onFavorite(templates[i]),
        ),
      ),
    );
  }
}

class StickerCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final p = Paint()..color = const Color(0xffededed);
    for (int y = 0; y < size.height / 12; y++) {
      for (int x = 0; x < size.width / 12; x++) {
        if ((x + y).isEven) {
          canvas.drawRect(Rect.fromLTWH(x * 12.0, y * 12.0, 12, 12), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(StickerCheckerPainter oldDelegate) => false;
}
