import 'package:flutter/services.dart';

class HapticService {
  const HapticService._();

  static Future<void> light() => HapticFeedback.lightImpact();
}
