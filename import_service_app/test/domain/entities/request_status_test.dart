import 'package:flutter_test/flutter_test.dart';

import 'package:import_service_app/domain/entities/request_status.dart';

void main() {
  group('RequestStatus.carsListTabIndex', () {
    test('in work statuses → tab 0', () {
      expect(RequestStatus.newRequest.carsListTabIndex, 0);
      expect(RequestStatus.onReview.carsListTabIndex, 0);
      expect(RequestStatus.inProgress.carsListTabIndex, 0);
    });

    test('in_transit → tab 1', () {
      expect(RequestStatus.inTransit.carsListTabIndex, 1);
    });

    test('delivered/closed/cancelled → tab 2', () {
      expect(RequestStatus.delivered.carsListTabIndex, 2);
      expect(RequestStatus.closed.carsListTabIndex, 2);
      expect(RequestStatus.cancelled.carsListTabIndex, 2);
    });
  });
}
