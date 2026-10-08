import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'config/config.dart';

/// Root widget of the LayerX application.
///
/// Wires up [ScreenUtil] for responsive sizing and GetX for navigation and
/// state management. Styling is intentionally lightweight — extend the
/// [ThemeData] below or introduce your own design tokens as the app grows.
class LayerXApp extends StatelessWidget {
  const LayerXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConfig.appName,
          theme: AppTheme.light,
          initialRoute: AppRoutes.splashView,
          getPages: AppPages.routes,
        );
      },
    );
  }
}
