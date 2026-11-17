import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/presentation/helpers/request_status_action_hint.dart';

CarListItem _item(String subType) => CarListItem(
      id: '1',
      ownerFullName: 'Test',
      carMake: 'Lexus',
      carModel: 'RX',
      vin: 'VIN0001',
      status: RequestStatus.inProgress,
      statusSubType: subType,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JsonStringsService strings;
  setUpAll(() async {
    strings = JsonStringsService();
    await strings.load(const Locale('ru'));
  });

  group('requestStatusActionHint originals', () {
    test('originalsComplete* → null (no reminder)', () {
      expect(
        requestStatusActionHint(_item('originals_complete_no_transit'), strings),
        isNull,
      );
      expect(
        requestStatusActionHint(_item('originals_complete_transit'), strings),
        isNull,
      );
    });

    test('originals partial/missing → originals reminder', () {
      for (final code in const [
        'originals_partial_no_transit',
        'originals_missing_transit',
        'originals_partial_transit',
      ]) {
        expect(
          requestStatusActionHint(_item(code), strings),
          strings.requestHintOriginalsToOffice,
          reason: code,
        );
      }
    });
  });
}
