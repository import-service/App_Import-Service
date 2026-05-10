/// API-статусы заявок. **Цвета чипа на списке** (красный фон / белый текст) — [RequestStatusListStyle] в
/// `lib/core/themes/request_status_list_style.dart`.
enum RequestStatus {
  newRequest('new'),
  inProgress('in_progress'),
  inTransit('in_transit'),
  delivered('delivered');

  const RequestStatus(this.apiValue);

  final String apiValue;

  static RequestStatus fromApiValue(String? value) {
    for (final status in RequestStatus.values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return RequestStatus.newRequest;
  }
}
