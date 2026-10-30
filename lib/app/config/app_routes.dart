import 'package:shared_preferences/shared_preferences.dart';

import '../mvvm/view/templates/template_preview_view.dart';

import 'package:get/get.dart';

import '../mvvm/view/home/home_view.dart';
import '../mvvm/view/splash/splash_view.dart';
import '../mvvm/view_model/home/home_controller.dart';
import '../mvvm/view_model/splash/splash_controller.dart';

abstract class AppRoutes {
  AppRoutes._();

  static const splashView = '/';
  static const homeView = '/home';
  static const templatePreview = '/template-preview';
}

abstract class AppPages {
  AppPages._();

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.templatePreview,
      page: () => const TemplatePreviewView(),
    ),
    GetPage(
      name: AppRoutes.splashView,
      page: () => const SplashView(),
      binding: BindingsBuilder(() {
        Get.put(SplashController(Get.find<SharedPreferences>()));
      }),
    ),
    GetPage(
      name: AppRoutes.homeView,
      page: () => const HomeView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<HomeController>(
          () => HomeController(Get.find<SharedPreferences>()),
        );
      }),
    ),
  ];
}
