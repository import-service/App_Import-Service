import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unified_image_picker/flutter_unified_image_picker.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_choice_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_photo_source_bottom_sheet.dart';

enum _DocumentPickKind { photo, pdf }

/// Фото/скан (камера) или PDF с устройства.
Future<String?> pickRequestDocumentPath(BuildContext context) async {
  final s = sl<JsonStringsService>();
  final choice = await AppChoiceBottomSheet.show<_DocumentPickKind>(
    context: context,
    title: s.requestPickDocumentTitle,
    options: [
      AppChoiceSheetOption(
        value: _DocumentPickKind.photo,
        label: s.requestPickDocumentPhoto,
        icon: Icons.photo_camera_outlined,
      ),
      AppChoiceSheetOption(
        value: _DocumentPickKind.pdf,
        label: s.requestPickDocumentPdf,
        icon: Icons.picture_as_pdf_outlined,
      ),
    ],
  );
  if (!context.mounted || choice == null) return null;
  if (choice == _DocumentPickKind.pdf) {
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
  // Документ: сразу камера (как раньше). Галерея — через кнопку в CameraView.
  return openAppCameraView(context);
}

/// Выбор источника и получение файлов (создание заявки / СВХ / архив).
///
/// Шторка [AppPhotoSourceBottomSheet]: галерея, камера или PDF («Файл»).
Future<List<String>> pickMultipleImagePaths({
  required BuildContext context,
  required int maxCount,
  bool allowFile = true,
}) async {
  if (maxCount <= 0) return const [];
  final source = await AppPhotoSourceBottomSheet.show(
    context,
    allowFile: allowFile,
  );
  if (!context.mounted || source == null) return const [];

  switch (source) {
    case AppPhotoSource.gallery:
      return _pickImagesFromGallery(maxCount: maxCount);
    case AppPhotoSource.camera:
      final path = await openAppCameraView(context);
      if (path == null || path.isEmpty) return const [];
      return [path];
    case AppPhotoSource.file:
      final path = await _pickPdfFile();
      if (path == null || path.isEmpty) return const [];
      return [path];
  }
}

/// Мультивыбор видео (для СВХ «Фото и видео машины», до [maxCount]).
Future<List<String>> pickMultipleVideoPaths({
  required int maxCount,
}) async {
  if (maxCount <= 0) return const [];
  final result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: true,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return const [];
  final paths = <String>[];
  for (final f in result.files) {
    final p = f.path;
    if (p == null || p.isEmpty) continue;
    paths.add(p);
    if (paths.length >= maxCount) break;
  }
  return paths;
}

/// Общий вход в экран камеры приложения ([CameraView]).
Future<String?> openAppCameraView(BuildContext context) {
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

Future<List<String>> _pickImagesFromGallery({required int maxCount}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: true,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return const [];
  final paths = <String>[];
  for (final f in result.files) {
    final p = f.path;
    if (p == null || p.isEmpty) continue;
    paths.add(p);
    if (paths.length >= maxCount) break;
  }
  return paths;
}

Future<String?> _pickPdfFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: false,
  );
  final path = result?.files.single.path;
  if (path == null || path.isEmpty) return null;
  return path;
}
