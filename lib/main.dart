import 'dart:async';
import 'app/services/ad_service.dart';
import 'app/services/purchase_service.dart';
import 'app/services/catalog_service.dart';
import 'app/services/remote_content.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'app/app_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Get.put<SharedPreferences>(
    await SharedPreferences.getInstance(),
    permanent: true,
  );
  await PurchaseService.initialize();
  await RemoteContent.loadCached();
  unawaited(CatalogService.warmCovers());
  runApp(const LayerXApp());
  if (!RemoteContent.needsFirstSetup(Get.find<SharedPreferences>())) {
    unawaited(RemoteContent.refresh());
  }
  unawaited(AdService.initialize());
}
