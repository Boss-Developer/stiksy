import 'package:flutter/material.dart';

import '../mvvm/model/sticker_template.dart';
import '../config/app_colors.dart';
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    shadowColor: const Color(0xff203f35).withValues(alpha: .10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.borderColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      onLongPress: onFavorite,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(template.color, Colors.white, .2)!,
                            Color.lerp(template.color, Colors.white, .7)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CustomPaint(
                          painter: const _TemplateBackdrop(),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: StickerArtwork(
                              template: template,
                              showBackground: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (template.premium)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff223d32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StiksyCrown(size: 13),
                            SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Color(0xffe5d4a0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .9),
                      ),
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: favorite
                            ? const Color(0xffd95c70)
                            : AppColors.textLightBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              template.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDarkColor,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLightBlack,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: AppColors.textLightBlack,
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
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
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          mainAxisExtent: constraints.maxWidth >= 650
              ? 250
              : (constraints.maxWidth - 12) / 2 + 105,
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

class _TemplateBackdrop extends CustomPainter {
  const _TemplateBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .85, size.height * .15);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [.4, .65, .9, 1.15]) {
      canvas.drawCircle(center, size.width * scale, paint);
    }
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .85),
      size.width * .28,
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(covariant _TemplateBackdrop oldDelegate) => false;
}
