import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_choice_bottom_sheet.dart';

/// Источник фото: галерея устройства или съёмка.
enum AppPhotoSource { gallery, camera }

/// Универсальная шторка «Галерея / Камера» для всего МП.
abstract final class AppPhotoSourceBottomSheet {
  static Future<AppPhotoSource?> show(
    BuildContext context, {
    String? title,
  }) {
    final s = sl<JsonStringsService>();
    return AppChoiceBottomSheet.show<AppPhotoSource>(
      context: context,
      title: title ?? s.text('requestPickPhotoSourceTitle'),
      options: [
        AppChoiceSheetOption(
          value: AppPhotoSource.gallery,
          label: s.text('requestPickPhotoSourceGallery'),
          icon: Icons.photo_library_outlined,
        ),
        AppChoiceSheetOption(
          value: AppPhotoSource.camera,
          label: s.text('requestPickPhotoSourceCamera'),
          icon: Icons.photo_camera_outlined,
        ),
      ],
    );
  }
}
