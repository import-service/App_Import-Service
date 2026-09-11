import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_choice_bottom_sheet.dart';

/// Источник вложения: галерея, камера или файл (PDF).
enum AppPhotoSource { gallery, camera, file }

/// Универсальная шторка «Галерея / Камера / Файл» для всего МП.
abstract final class AppPhotoSourceBottomSheet {
  static Future<AppPhotoSource?> show(
    BuildContext context, {
    String? title,
    bool allowFile = true,
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
        if (allowFile)
          AppChoiceSheetOption(
            value: AppPhotoSource.file,
            label: s.text('requestPickPhotoSourceFile'),
            icon: Icons.attach_file,
          ),
      ],
    );
  }
}
