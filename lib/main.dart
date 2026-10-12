import 'dart:async';

import 'app/services/ad_service.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'app/app_widget.dart';
import 'app/config/config.dart';
import 'app/services/logger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggerService.banner(name: AppConfig.appName, env: 'debug');

  Get.put<SharedPreferences>(
    await SharedPreferences.getInstance(),
    permanent: true,
  );
  runApp(const LayerXApp());
  unawaited(AdService.initialize());
}
