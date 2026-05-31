import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unified_image_picker/flutter_unified_image_picker.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';

/// Фото/скан (камера/галерея) или PDF с устройства.
Future<String?> pickRequestDocumentPath(BuildContext context) async {
  final s = sl<JsonStringsService>();
  final choice = await AppModalBottomSheet.show<String>(
    context: context,
    child: Builder(
      builder: (sheetContext) => Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: s.requestPickDocumentTitle),
            InkWell(
              onTap: () => Navigator.pop(sheetContext, 'photo'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined),
                    const Gap(12),
                    Expanded(child: Text(s.requestPickDocumentPhoto)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined),
                    const Gap(12),
                    Expanded(child: Text(s.requestPickDocumentPdf)),
                  ],
                ),
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return null;
  if (choice == 'pdf') {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return null;
    return path;
  }
  if (!context.mounted) return null;
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        child: const CameraView(hideGalleryInSheet: true),
      ),
    ),
  );
}
