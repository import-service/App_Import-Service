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
    this.storedName,
    this.sourceFileName,
    this.sourceMimeType,
    this.uploadSource,
  });

  final String id;
  final String docType;
  final String fileName;
  final String fileUrl;
  final String? previewUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? storedName;
  /// Имя файла как пришло в upload (до нормализации).
  final String? sourceFileName;
  /// mimeType как пришёл в upload (до детекта).
  final String? sourceMimeType;
  /// `integration` | `user` | `demo`
  final String? uploadSource;

  @override
  List<Object?> get props => [
        id,
        docType,
        fileUrl,
        previewUrl,
        sourceFileName,
        sourceMimeType,
        uploadSource,
      ];

  /// URL для превью в списках; fallback — полный fileUrl.
  String get displayUrl => (previewUrl != null && previewUrl!.trim().isNotEmpty)
      ? previewUrl!.trim()
      : fileUrl;

  bool get fromOneC => uploadSource == 'integration';
}
