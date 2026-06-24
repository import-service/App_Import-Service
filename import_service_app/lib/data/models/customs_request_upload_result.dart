import 'package:import_service_app/domain/entities/car_list_item.dart';

/// Ответ `POST /api/customs-requests/upload` (контракт v2).
final class CustomsRequestUploadResponse {
  const CustomsRequestUploadResponse({
    required this.ok,
    required this.batchComplete,
    this.docType,
    this.fileUrl,
    this.previewUrl,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.replaced = false,
  });

  final bool ok;
  final bool batchComplete;
  final String? docType;
  final String? fileUrl;
  final String? previewUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final bool replaced;
}

/// Create без files в теле + батч upload (data layer).
final class CreateRequestResult {
  const CreateRequestResult({
    required this.item,
    this.failedDocTypes = const [],
  });

  final CarListItem item;
  final List<String> failedDocTypes;

  bool get allFilesUploaded => failedDocTypes.isEmpty;
}
