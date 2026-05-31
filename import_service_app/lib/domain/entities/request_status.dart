/// API-статусы заявок. **Цвета чипа на списке** — [RequestStatusListStyle] в
/// `lib/core/themes/request_status_list_style.dart`.
enum RequestStatus {
  newRequest('new'),
  onReview('on_review'),
  inProgress('in_progress'),
  inTransit('in_transit'),
  delivered('delivered'),
  closed('closed'),
  cancelled('cancelled');

  const RequestStatus(this.apiValue);

  final String apiValue;

  static RequestStatus fromApiValue(String? value) {
    final v = (value ?? '').trim();
    for (final status in RequestStatus.values) {
      if (status.apiValue == v) {
        return status;
      }
    }
    return RequestStatus.newRequest;
  }

  /// Чип на главной: 0 — в работе, 1 — в пути, 2 — доставлено.
  int get carsListTabIndex {
    switch (this) {
      case RequestStatus.newRequest:
      case RequestStatus.onReview:
      case RequestStatus.inProgress:
        return 0;
      case RequestStatus.inTransit:
        return 1;
      case RequestStatus.delivered:
      case RequestStatus.closed:
      case RequestStatus.cancelled:
        return 2;
    }
  }
}
