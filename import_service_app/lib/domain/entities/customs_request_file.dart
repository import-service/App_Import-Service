import 'package:equatable/equatable.dart';

/// Вложенный файл заявки ([api-app.md] — `files[]` на `GET :id` / созднии).
final class CustomsRequestFile extends Equatable {
  const CustomsRequestFile({
    this.id,
    this.docType,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.fileUrl,
    this.createdAt,
  });

  final String? id;
  final String? docType;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? fileUrl;
  final String? createdAt;

  factory CustomsRequestFile.fromJson(Map<String, dynamic> json) {
    final size = json['fileSizeBytes'] ?? json['file_size_bytes'];
    return CustomsRequestFile(
      id: json['id']?.toString(),
      docType: json['docType'] as String? ?? json['doc_type'] as String?,
      fileName: json['fileName'] as String? ?? json['file_name'] as String?,
      mimeType: json['mimeType'] as String? ?? json['mime_type'] as String?,
      fileSizeBytes: size is int ? size : (size is num) ? size.toInt() : null,
      fileUrl: json['fileUrl'] as String? ?? json['file_url'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        if (docType != null) 'docType': docType,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (createdAt != null) 'createdAt': createdAt,
      };

  @override
  List<Object?> get props =>
      [id, docType, fileName, mimeType, fileSizeBytes, fileUrl, createdAt];
}
