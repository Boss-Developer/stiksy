import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// Points path_provider at a fresh temp directory and returns it.
Directory installFakePaths() {
  final dir = Directory.systemTemp.createTempSync('stiksy_test');
  PathProviderPlatform.instance = _FakePaths(dir.path);
  return dir;
}
