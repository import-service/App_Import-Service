import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';

/// Подпись кнопки загрузки в секции «На подпись» с учётом типа документа.
String signingUploadActionLabel({
  required CustomsDocType baseDocType,
  required JsonStringsService strings,
  required bool hasSignedFile,
}) {
  if (hasSignedFile) {
    return strings.requestUploadDocAgain;
  }
  final docName = docTypeLabelForType(baseDocType, strings);
  if (baseDocType.isClientSignOnly) {
    return strings.requestUploadDocFile(docName);
  }
  return strings.requestUploadSignedButton;
}
