import 'package:equatable/equatable.dart';

class CustomsRequestFile extends Equatable {
  const CustomsRequestFile({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.previewUrl,
  });

  final String id;
  final String docType;
  final String fileName;
  final String fileUrl;
  final String? previewUrl;
  final String? mimeType;
  final int? fileSizeBytes;

  @override
  List<Object?> get props => [id, docType, fileUrl, previewUrl];

  /// URL для превью в списках; fallback — полный fileUrl.
  String get displayUrl => (previewUrl != null && previewUrl!.trim().isNotEmpty)
      ? previewUrl!.trim()
      : fileUrl;
}
