import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../custom_widgets/sticker_components.dart';
import '../../../services/template_access.dart';
import '../../model/sticker_template.dart';
import '../editor/sticker_editor_view.dart';
import '../../view_model/home/home_controller.dart';

class TemplatePreviewView extends GetView<HomeController> {
  const TemplatePreviewView({super.key});
  @override
  Widget build(BuildContext context) {
    final template = Get.arguments;
    if (template is! StickerTemplate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Template preview')),
        body: const Center(child: Text('Choose a template from the gallery.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Template preview')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: () async {
              if (await TemplateAccess.allow(context, template)) {
                Get.to(() => StickerEditorView(template: template));
              }
            },
            child: const Text('Use This Template'),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: StickerCheckerPainter(),
                      child: StickerArtwork(
                        template: template,
                        showBackground: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              template.premium ? 'Premium' : 'Free',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () => IconButton(
                          tooltip: controller.favorites.contains(template.id)
                              ? 'Saved to favorites'
                              : 'Save to favorites',
                          onPressed: () => controller.toggleFavorite(template),
                          icon: Icon(
                            controller.favorites.contains(template.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: const Color(0xffff4b75),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Similar Templates',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: stickerTemplates
                          .where(
                            (t) =>
                                t.category == template.category &&
                                t.id != template.id,
                          )
                          .length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final t = stickerTemplates
                            .where(
                              (t) =>
                                  t.category == template.category &&
                                  t.id != template.id,
                            )
                            .elementAt(i);
                        return SizedBox(
                          width: 98,
                          child: InkWell(
                            onTap: () async {
                              if (await TemplateAccess.allow(context, t)) {
                                Get.to(() => StickerEditorView(template: t));
                              }
                            },
                            child: StickerArtwork(template: t),
                          ),
                        );
                      },
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
}
