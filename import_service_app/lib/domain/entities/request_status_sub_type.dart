import 'package:import_service_app/domain/entities/request_status.dart';

/// Подстатус заявки из 1С (`statusSubType`). Синхрон с `customsCatalog.js`.
enum RequestStatusSubType {
  draft('draft', RequestStatus.onReview),
  managerExecution('manager_execution', RequestStatus.inProgress),
  primaryDocumentsSent('primary_documents_sent', RequestStatus.inProgress),
  originalsPartialNoTransit('originals_partial_no_transit', RequestStatus.inProgress),
  originalsCompleteNoTransit('originals_complete_no_transit', RequestStatus.inProgress),
  signatureRevisionRequired('signature_revision_required', RequestStatus.inProgress),
  originalsMissingTransit('originals_missing_transit', RequestStatus.inTransit),
  originalsPartialTransit('originals_partial_transit', RequestStatus.inTransit),
  originalsCompleteTransit('originals_complete_transit', RequestStatus.inTransit),
  svhNoOriginalsNoRecycling('svh_no_originals_no_recycling', RequestStatus.delivered),
  svhPartialDocsNoRecycling('svh_partial_docs_no_recycling', RequestStatus.delivered),
  svhNoOriginalsRecycling('svh_no_originals_recycling', RequestStatus.delivered),
  svhPartialDocsRecycling('svh_partial_docs_recycling', RequestStatus.delivered),
  svhAllDocsNoRecycling('svh_all_docs_no_recycling', RequestStatus.delivered),
  svhAllDocsRecycling('svh_all_docs_recycling', RequestStatus.delivered),
  ptdSubmitted('ptd_submitted', RequestStatus.delivered),
  ptdSubmittedPaid('ptd_submitted_paid', RequestStatus.delivered),
  ptdRelease('ptd_release', RequestStatus.delivered),
  sentToLab('sent_to_lab', RequestStatus.delivered),
  issuedToClient('issued_to_client', RequestStatus.delivered),
  requestClosed('request_closed', RequestStatus.closed);

  const RequestStatusSubType(this.apiCode, this.typicalStatus);

  final String apiCode;
  final RequestStatus typicalStatus;

  static final Map<String, RequestStatusSubType> _byCode = {
    for (final v in RequestStatusSubType.values) v.apiCode: v,
  };

  static String normalizeCode(String? raw) {
    final code = (raw ?? '').trim();
    if (code.isEmpty) return '';
    if (code == 'manager_assigned') {
      return RequestStatusSubType.managerExecution.apiCode;
    }
    return code;
  }

  static RequestStatusSubType? tryParse(String? raw) {
    final code = normalizeCode(raw);
    if (code.isEmpty) return null;
    return _byCode[code];
  }
}
