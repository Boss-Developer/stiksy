import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiksy/app/services/app_gate.dart';

void main() {
  test('the update prompt always has somewhere to send the user', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      AppGate.storeUri('', 'com.sfdevelopers.stiksy').toString(),
      'https://play.google.com/store/apps/details?id=com.sfdevelopers.stiksy',
    );
    expect(
      AppGate.storeUri(' https://example.com/stiksy ', 'x').toString(),
      'https://example.com/stiksy',
    );
  });

  test('without a store link on iOS the prompt can be closed instead', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(AppGate.storeUri('', 'com.sfdevelopers.stiksy'), isNull);
  });
}
