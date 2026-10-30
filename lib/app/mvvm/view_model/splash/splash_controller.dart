import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_routes.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../services/remote_content.dart';

enum SplashPhase { logo, loading }

typedef SetupReport = void Function(double progress, String label);

class SplashController extends GetxController {
  SplashController(
    this.preferences, {
    Future<BootstrapStatus> Function(SetupReport report)? bootstrap,
    bool Function()? needsSetup,
    this.minimumSetupTime = const Duration(milliseconds: 1200),
  }) : _bootstrap = bootstrap ?? RemoteContent.bootstrap,
       _needsSetup =
           needsSetup ?? (() => RemoteContent.needsFirstSetup(preferences));

  final SharedPreferences preferences;
  final Future<BootstrapStatus> Function(SetupReport report) _bootstrap;
  final bool Function() _needsSetup;

  final Duration minimumSetupTime;

  final ready = false.obs;
  final phase = SplashPhase.logo.obs;
  final progress = 0.0.obs;
  final label = ''.obs;
  Timer? _timer;
  bool _finishing = false;

  @override
  void onReady() {
    super.onReady();
    if (_needsSetup()) {
      unawaited(runSetup());
      return;
    }
    final returning = preferences.getBool('stiksy_onboarded') ?? false;
    _timer = Timer(Duration(milliseconds: returning ? 700 : 2000), () {
      if (isClosed) return;
      ready.value = true;
      finish();
    });
  }

  Future<void> runSetup() async {
    phase.value = SplashPhase.loading;
    progress.value = 0;
    label.value = 'Getting things ready…';
    final shown = Future<void>.delayed(minimumSetupTime);
    BootstrapStatus status;
    try {
      status = await _bootstrap((p, l) {
        if (isClosed) return;
        progress.value = p.clamp(0, 1).toDouble();
        label.value = l;
      });
    } catch (_) {
      status = BootstrapStatus.failed;
    }
    await shown;
    if (isClosed) return;
    if (status == BootstrapStatus.ready) {
      ready.value = true;
      await finish();
      return;
    }
    // A first impression should never be an error screen: open with the
    // built-in designs; the rest downloads on a later launch.
    await continueOffline();
    'You’re seeing the built-in designs. More will download once you’re online.'
        .showInfo();
  }

  Future<void> continueOffline() async {
    await preferences.setBool(RemoteContent.skipSetupKey, true);
    ready.value = true;
    await finish();
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
