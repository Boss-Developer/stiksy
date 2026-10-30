import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../custom_widgets/snackbars/app_snackbar.dart';
import 'happy_moments.dart';

/// Turns any failure into a sentence a non-technical person understands.
/// The technical detail only goes to the debug log, never on screen.
String friendlyError(Object error, String fallback) {
  debugPrint('Stiksy: $error');
  if (error is! PlatformException) return fallback;
  switch (error.code) {
    case 'whatsapp_unavailable':
      return 'Please install or update WhatsApp first.';
    case 'gallery_permission':
    case 'gallery_denied':
      return 'Allow photo access for Stiksy in your phone settings to save stickers.';
    case 'invalid_webp':
      return 'This sticker is too detailed for WhatsApp. Try a smaller photo or fewer layers.';
    case 'pack_count':
      // Written by us and already friendly.
      return error.message ?? fallback;
  }
  return fallback;
}

/// Shows the outcome of asking WhatsApp to add a sticker pack. Success is the
/// best moment in the app, so it gets a celebration, not a toast.
Future<void> showPackResult(Map<String, dynamic> result) async {
  switch (result['status']) {
    case 'added':
      await HappyMoments.packAdded();
    case 'rejected':
      debugPrint('Stiksy: WhatsApp rejected pack: ${result['message']}');
      'WhatsApp couldn’t add this pack. Please try again.'.showError();
    default:
      'Not added to WhatsApp. Your stickers are still saved here.'.showInfo();
  }
}
