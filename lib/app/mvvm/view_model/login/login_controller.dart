import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../custom_widgets/snackbars/app_snackbar.dart';
import '../../../repository/auth_repository.dart';
import '../../model/body_model/login_request_model.dart';

class LoginController extends GetxController {
  LoginController(this._authRepository);

  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final obscurePassword = true.obs;

  void togglePasswordVisibility() => obscurePassword.toggle();

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  Future<void> login() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;
    try {
      final response = await _authRepository.login(
        LoginRequestModel(
          email: emailController.text.trim(),
          password: passwordController.text,
        ),
      );

      if (response.success == true) {
        'Welcome, ${response.data?.name ?? 'there'} 👋'.showSuccess();
        // Navigating away disposes this controller, so we must not mutate any
        // state (isLoading) afterwards — return before the clean-up below.
        await Get.offAllNamed(AppRoutes.homeView);
        return;
      }

      (response.message ?? 'Login failed. Please try again.').showError();
    } catch (_) {
      'Something went wrong. Please try again.'.showError();
    }
    isLoading.value = false;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
