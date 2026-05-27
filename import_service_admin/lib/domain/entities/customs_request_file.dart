import 'package:equatable/equatable.dart';

class CustomsRequestFile extends Equatable {
  const CustomsRequestFile({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.fileSizeBytes,
  });

  final String id;
  final String docType;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final int? fileSizeBytes;

  @override
  List<Object?> get props => [id, docType, fileUrl];
}
