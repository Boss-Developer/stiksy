import 'package:flutter/material.dart';

import '../custom_widgets/snackbars/app_snackbar.dart';
import 'ad_service.dart';

/// Plays a rewarded video the friendly way: says what is happening while it
/// loads, lets the user back out, and offers another go if they stop early.
/// Returns true when the user should get [unlock].
Future<bool> watchForReward(
  BuildContext context, {
  required String unlock,
}) async {
  while (true) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: const Row(
            children: [
              SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Loading a short video…\nThis usually takes a few seconds.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: AdService.cancelLoading,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    final reward = await AdService.requestReward();
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    switch (reward) {
      case RewardResult.earned:
        return true;
      case RewardResult.unavailable:
        'No video available right now, so this one’s on us.'.showSuccess();
        return true;
      case RewardResult.cancelled:
        return false;
      case RewardResult.dismissed:
        final again = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('The video stopped early'),
            content: Text('Watch it to the end to $unlock. Try again?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Watch again'),
              ),
            ],
          ),
        );
        if (again != true || !context.mounted) return false;
    }
  }
}
