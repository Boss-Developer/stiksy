import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_routes.dart';

class SplashController extends GetxController {
  SplashController(this.preferences);
  final SharedPreferences preferences;
  final ready = false.obs;
  Timer? _timer;
  bool _finishing = false;
  @override
  void onReady() {
    super.onReady();
    _timer = Timer(const Duration(seconds: 3), () {
      if (isClosed) return;
      ready.value = true;
      finish();
    });
  }

  Future<void> finish() async {
    if (!ready.value || _finishing || isClosed) return;
    _finishing = true;
    await preferences.setBool('stiksy_onboarded', true);
    if (!isClosed) Get.offAllNamed(AppRoutes.homeView);
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
