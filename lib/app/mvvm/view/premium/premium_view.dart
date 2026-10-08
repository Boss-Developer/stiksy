import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../custom_widgets/stiksy_crown.dart';

class PremiumView extends StatefulWidget {
  const PremiumView({super.key});
  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  bool yearly = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff546b79),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: StiksyCrown(size: 64)),
              const SizedBox(height: 12),
              const Text(
                'Go Premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Remove watermark, unlock all templates,\nfonts and effects.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ...[
                      'No watermark',
                      'Unlock all premium templates',
                      'Unlock all fonts & effects',
                      'Remove all ads',
                      'Support future updates',
                    ].map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: AppColors.primary,
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(label)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        plan(false, 'Monthly', 'Rs 399', 'per month'),
                        const SizedBox(width: 12),
                        plan(true, 'Yearly', 'Rs 1,999', 'Save 58%'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Subscriptions are coming soon.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: null,
                        child: const Text('Continue'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Maybe later'),
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
  Widget plan(
    bool annual,
    String label,
    String price,
    String detail,
  ) => Expanded(
    child: InkWell(
      onTap: () => setState(() => yearly = annual),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xfffafafa),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: yearly == annual ? AppColors.primary : Colors.black12,
            width: yearly == annual ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: AppColors.primary, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}
