import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../buttons/app_button.dart';

/// Lightweight dialog shown when the app cannot reach the server. Presented
/// through GetX so it can be triggered from anywhere without a [BuildContext].
class NoInternetDialog {
  const NoInternetDialog._();

  static Future<void> show({
    required String title,
    required String message,
    String closeText = 'Dismiss',
    VoidCallback? onClose,
  }) {
    return Get.dialog(
      Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 44.r,
                color: AppColors.primary,
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              SizedBox(height: 20.h),
              AppButton(
                label: closeText,
                width: double.infinity,
                onPressed: () {
                  if (Get.isDialogOpen ?? false) Get.back();
                  onClose?.call();
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
