import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';

/// Префикс в [ServerFailure.message] от `attachRequestFiles` (data layer).
const kRequestAttachFailedPrefix = 'Не удалось загрузить: ';

/// Человекочитаемое сообщение об ошибке загрузки (docType → подпись из i18n).
String requestAttachFailureMessage(String rawMessage, JsonStringsService strings) {
  if (!rawMessage.startsWith(kRequestAttachFailedPrefix)) {
    return rawMessage;
  }
  final codesPart = rawMessage.substring(kRequestAttachFailedPrefix.length).trim();
  if (codesPart.isEmpty) {
    return strings.requestFileAttachFailedGeneric;
  }
  final labels = codesPart
      .split(',')
      .map((code) => docTypeLabelForCode(code.trim(), strings))
      .join(', ');
  return strings.requestFileAttachFailed(labels);
}
